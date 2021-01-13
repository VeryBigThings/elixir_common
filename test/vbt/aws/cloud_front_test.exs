defmodule VBT.Aws.CloudFrontTest do
  use ExUnit.Case, async: true

  alias VBT.Aws.CloudFront

  describe "download_url" do
    test "properly encodes url" do
      decoded_url = decoded_download_url("some bucket", "/some/path")
      assert decoded_url.scheme == "https"
      assert decoded_url.host == "asset.cloudfront.net"
      assert decoded_url.key_pair_id == "some_key_pair_id"
      assert decoded_url.resource == %{"bucket" => "some bucket", "key" => "/some/path"}

      # due to timing imprecision this expiry might be larger (usually no more than 1 sec)
      assert decoded_url.expires_in >= 10
    end

    test "encodes extra params in the resource" do
      assert decoded_download_url("some bucket", "/some/path", foo: "bar").resource ==
               %{"bucket" => "some bucket", "key" => "/some/path", "foo" => "bar"}
    end

    test "accepts hostable as a target object" do
      assert decoded_download_url("some bucket", VBT.TestAsset.new("/another/path")).resource ==
               %{"bucket" => "some bucket", "key" => "/another/path"}
    end
  end

  describe "cookies/2" do
    test "encodes the given path" do
      cookies = CloudFront.cookies(config(), "/*")
      encoded_policy = Enum.into(cookies, %{}, fn {"CloudFront-" <> k, v} -> {k, v} end)
      assert %{"Statement" => [%{"Resource" => uri}]} = decode_policy!(encoded_policy)
      assert URI.parse(uri).path == "/*"
    end
  end

  describe "cookies/4" do
    test "returns the map with expected keys" do
      cookies = CloudFront.cookies(config(), "some bucket", "/some/path")

      assert Map.keys(cookies) ==
               ~w/CloudFront-Key-Pair-Id CloudFront-Policy CloudFront-Signature/
    end

    test "properly encodes bucket and path" do
      cookies = CloudFront.cookies(config(), "some bucket", "/some/path")
      assert decode_cookies(cookies) == %{"bucket" => "some bucket", "key" => "/some/path"}
    end
  end

  defp decode_cookies(cookies) do
    encoded_policy = Enum.into(cookies, %{}, fn {"CloudFront-" <> k, v} -> {k, v} end)
    policy = decode_policy!(encoded_policy)
    decode_resource!(policy)
  end

  defp decoded_download_url(bucket, object, params \\ []) do
    url = CloudFront.download_url(config(), bucket, object, params)
    uri = URI.parse(url)
    encoded_policy = URI.decode_query(uri.query)
    policy = decode_policy!(encoded_policy)

    %{
      scheme: uri.scheme,
      host: uri.host,
      key_pair_id: Map.fetch!(encoded_policy, "Key-Pair-Id"),
      expires_in: decode_expires_in(policy, DateTime.utc_now()),
      resource: decode_resource!(policy)
    }
  end

  defp decode_policy!(query) do
    query
    |> Map.fetch!("Policy")
    |> safe_decode_base64!()
    |> Jason.decode!()
  end

  defp safe_decode_base64!(encoded) do
    encoded
    |> String.replace("~", "/")
    |> String.replace("_", "=")
    |> String.replace("-", "+")
    |> Base.decode64!()
  end

  defp decode_expires_in(policy, now) do
    policy
    |> Map.fetch!("Statement")
    |> hd()
    |> Map.fetch!("Condition")
    |> Map.fetch!("DateLessThan")
    |> Map.fetch!("AWS:EpochTime")
    |> DateTime.from_unix!()
    |> DateTime.diff(now)
  end

  defp decode_resource!(policy) do
    policy
    |> Map.fetch!("Statement")
    |> hd()
    |> Map.fetch!("Resource")
    |> URI.parse()
    |> Map.fetch!(:path)
    |> String.replace(~r(^/), "")
    |> Base.decode64!()
    |> Jason.decode!()
  end

  defp config do
    %{
      host: "asset.cloudfront.net",
      key_pair_id: "some_key_pair_id",
      private_key: private_key(),
      url_expires_in_sec: 10
    }
  end

  defp private_key do
    ExPublicKey.loads!("""
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEAli7V49NdZe+XYC1pLaHM0te8kiDmZBJ1u2HJHN8GdbROB6NO
    VpC3xK7NxQn6xpvZ9ux20NvcDvGle+DOptZztBH+np6h2jZQ1/kD1yG1eQvVH4th
    /9oqHuIjmIfO8lIe4Hyd5Fw5xHkGqVETTGR+0c7kdZIlHmkOregUGtMYZRUi4YG+
    q0w+uFemiHpGKXbeCIAvkq7aIkisEzvPWfSyYdA6WJHpxFk7tD7D8VkzABLVRHCq
    AuyqPG39BhGZcGLXx5rGK56kDBJkyTR1t3DkHpwX+JKNG5UYNwOG4LcQj1fteeta
    TdkYUMjIyWbanlMYyC+dq7B5fe7el99jXQ1gXwIDAQABAoIBADKfiPOpzKLOtzzx
    MbHzB0LO+75aHq7+1faayJrVxqyoYWELuB1P3NIMhknzyjdmU3t7S7WtVqkm5Twz
    lBUC1q+NHUHEgRQ4GNokExpSP4SU63sdlaQTmv0cBxmkNarS6ZuMBgDy4XoLvaYX
    MSUf/uukDLhg0ehFS3BteVFtdJyllhDdTenF1Nb1rAeN4egt8XLsE5NQDr1szFEG
    xH5lb+8EDtzgsGpeIddWR64xP0lDIKSZWst/toYKWiwjaY9uZCfAhvYQ1RsO7L/t
    sERmpYgh+rAZUh/Lr98EI8BPSPhzFcSHmtqzzejvC5zrZPHcUimz0CGA3YBiLoJX
    V1OrxmECgYEAxkd8gpmVP+LEWB3lqpSvJaXcGkbzcDb9m0OPzHUAJDZtiIIf0UmO
    nvL68/mzbCHSj+yFjZeG1rsrAVrOzrfDCuXjAv+JkEtEx0DIevU1u60lGnevOeky
    r8Be7pmymFB9/gzQAd5ezIlTv/COgoO986a3h1yfhzrrzbqSiivw308CgYEAwecI
    aZZwqH3GifR+0+Z1B48cezA5tC8LZt5yObGzUfxKTWy30d7lxe9N59t0KUVt/QL5
    qVkd7mqGzsUMyxUN2U2HVnFTWfUFMhkn/OnCnayhILs8UlCTD2Xxoy1KbQH/9FIr
    xf0pbMNJLXeGfyRt/8H+BzSZKBw9opJBWE4gqfECgYBp9FdvvryHuBkt8UQCRJPX
    rWsRy6pY47nf11mnazpZH5Cmqspv3zvMapF6AIxFk0leyYiQolFWvAv+HFV5F6+t
    Si1mM8GCDwbA5zh6pEBDewHhw+UqMBh63HSeUhmi1RiOwrAA36CO8i+D2Pt+eQHv
    ir52IiPJcs4BUNrv5Q1BdwKBgBHgVNw3LGe8QMOTMOYkRwHNZdjNl2RPOgPf2jQL
    d/bFBayhq0jD/fcDmvEXQFxVtFAxKAc+2g2S8J67d/R5Gm/AQAvuIrsWZcY6n38n
    pfOXaLt1x5fnKcevpFlg4Y2vM4O416RHNLx8PJDehh3Oo/2CSwMrDDuwbtZAGZok
    icphAoGBAI74Tisfn+aeCZMrO8KxaWS5r2CD1KVzddEMRKlJvSKTY+dOCtJ+XKj1
    OsZdcDvDC5GtgcywHsYeOWHldgDWY1S8Z/PUo4eK9qBXYBXp3JEZQ1dqzFdz+Txi
    rBn2WsFLsxV9j2/ugm0PqWVBcU2bPUCwvaRu3SOms2teaLwGCkhr
    -----END RSA PRIVATE KEY-----
    """)
  end
end
