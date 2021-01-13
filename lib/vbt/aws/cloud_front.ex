defmodule VBT.Aws.CloudFront do
  @moduledoc "Helper for performing actions on CloudFront."

  alias VBT.Aws.S3

  @type config :: %{
          host: String.t(),
          key_pair_id: String.t(),
          private_key: %ExPublicKey.RSAPrivateKey{},
          url_expires_in_sec: pos_integer
        }

  @doc "Returns the signed and encoded download URL for the given `S3.Hostable` object."
  @spec download_url(config, String.t(), S3.Hostable.t(), map | Keyword.t()) :: String.t()
  def download_url(config, bucket, object, params \\ []),
    do: sign_url(config, uri(config, bucket, object, params))

  @doc "Returns the cookies which can be used in the browser to access the given hostable object."
  @spec cookies(config, String.t(), S3.Hostable.t(), map | Keyword.t()) ::
          %{String.t() => String.t()}
  def cookies(config, bucket, object, params \\ []) do
    config
    |> cdn_params(uri(config, bucket, object, params))
    |> Enum.into(%{}, fn {key, value} -> {"CloudFront-#{key}", value} end)
  end

  defp uri(config, bucket, object, params) do
    path =
      %{bucket: bucket, key: S3.Hostable.path(object)}
      |> Map.merge(Map.new(params))
      |> Jason.encode!()
      |> Base.encode64()

    %URI{scheme: "https", host: config.host, path: "/#{path}"}
  end

  defp sign_url(config, uri),
    do: URI.to_string(%URI{uri | query: URI.encode_query(cdn_params(config, uri))})

  defp cdn_params(config, uri) do
    expires_at = expiration_time(config.url_expires_in_sec)
    raw_policy = build_policy(to_string(uri), expires_at)
    policy = safe_base64(raw_policy)
    signature = sign_policy(raw_policy, config.private_key)

    %{
      "Key-Pair-Id" => config.key_pair_id,
      "Policy" => policy,
      "Signature" => signature
    }
  end

  defp build_policy(uri, expires_at) do
    policy = %{
      "Statement" => [
        %{
          "Resource" => uri,
          "Condition" => %{
            "DateLessThan" => %{
              "AWS:EpochTime" => expires_at
            }
          }
        }
      ]
    }

    Jason.encode!(policy)
  end

  defp sign_policy(data, private_key) do
    {:ok, signature} = ExPublicKey.sign(data, :sha, private_key)
    safe_base64(signature)
  end

  # Base64-encodes the hashed and signed policy statement and replaces special characters to
  # make the string safe to use as a URL request parameter.
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html
  defp safe_base64(data) do
    data
    |> Base.encode64()
    |> String.replace("+", "-")
    |> String.replace("=", "_")
    |> String.replace("/", "~")
  end

  defp expiration_time(expires_in_sec) do
    DateTime.utc_now()
    |> DateTime.add(expires_in_sec)
    |> DateTime.to_unix()
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end
