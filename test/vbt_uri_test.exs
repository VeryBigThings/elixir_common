defmodule VbtURITest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest VbtURI

  describe "to_string/1" do
    property "preserves scheme, host, and port" do
      check all uri <- uri() do
        vbt_uri = uri |> VbtURI.to_string() |> URI.parse()

        assert vbt_uri.scheme == uri.scheme
        assert vbt_uri.host == uri.host
        assert vbt_uri.port == uri.port
      end
    end

    property "sets path to /" do
      check all uri <- uri() do
        vbt_uri = uri |> VbtURI.to_string() |> URI.parse()
        assert vbt_uri.path == "/"
      end
    end

    property "encodes path, query, and fragment into fragment which starts with !" do
      check all uri <- uri() do
        encoded_fragment = (uri |> VbtURI.to_string() |> URI.parse()).fragment
        expected_fragment = "!" <> URI.to_string(%URI{uri | scheme: nil, host: nil, port: nil})
        assert encoded_fragment == expected_fragment
      end
    end

    test "raises if path starts with /" do
      uri = %URI{Enum.at(uri(), 1) | path: "/"}
      expected_message = "the input path must not start with /"
      assert_raise ArgumentError, expected_message, fn -> VbtURI.to_string(uri) end
    end
  end

  describe "parse/1" do
    property "returns the original input passed to to_string/1" do
      check all uri <- uri() do
        assert uri |> VbtURI.to_string() |> VbtURI.parse() == uri
      end
    end

    test "raises if path is not empty" do
      assert_raise ArgumentError, fn -> VbtURI.parse("http://some_server/foo/bar#!a=1") end
    end

    test "raises if query is not empty" do
      assert_raise ArgumentError, fn -> VbtURI.parse("http://some_server/?foo=1#!a=1") end
    end

    test "raises if fragment doesn't start with !" do
      assert_raise ArgumentError, fn -> VbtURI.parse("http://some_server/#a=1") end
    end
  end

  defp uri do
    gen all scheme <- constant_of(~w/http https/),
            port <- one_of([default_port(scheme), non_default_port(scheme)]),
            uri <-
              fixed_map(%{
                scheme: constant(scheme),
                host: host(),
                port: constant(port),
                path: one_of([constant(nil), multipart_string("/")]),
                query: one_of([constant(nil), query()]),
                fragment: one_of([constant(nil), alphanumeric_string()])
              }),
            do: struct!(URI, uri)
  end

  defp default_port("http"), do: constant(80)
  defp default_port("https"), do: constant(443)

  defp non_default_port(scheme), do: filter(integer(1..65_535), &(&1 != default_port(scheme)))

  defp host, do: one_of([constant("localhost"), multipart_string("."), ip_address()])

  defp query do
    gen all params <- map_of(alphanumeric_string(), alphanumeric_string()),
            do: URI.encode_query(params)
  end

  defp ip_address do
    integer(0..999)
    |> List.duplicate(4)
    |> fixed_list()
    |> map(&Enum.join(&1, "."))
  end

  defp multipart_string(separator) do
    alphanumeric_string()
    |> list_of()
    |> nonempty()
    |> map(&Enum.join(&1, separator))
  end

  defp alphanumeric_string, do: string(:alphanumeric, min_length: 1)

  defp constant_of(elements), do: one_of(Enum.map(elements, &constant/1))
end
