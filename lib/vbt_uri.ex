defmodule VbtURI do
  @moduledoc """
  Encoding and decoding of VBT URIs.

  A VBT URI is a special format of URI where path, query, and fragment parts are encoded into the
  fragment. For example, a standard URI http://some.host/some/path?foo=1#some_fragment is
  represented as http://some.host/#!some/path?foo=1#some_fragment.

  This special URI format is introduced to support deep links with applications deployed to S3.
  By encoding everything into fragment, we make sure that every link always points to the root
  (index.html) on the S3 server.
  """

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Returns the string representation of the given URI, encoded in VBT format.

      iex> uri = %URI{
      ...>   scheme: "http",
      ...>   host: "foo.bar",
      ...>   port: 4000,
      ...>   path: "/some/path",
      ...>   query: "foo=1&bar=2",
      ...>   fragment: "some_fragment"
      ...> }
      iex> VbtURI.to_string(uri)
      "http://foo.bar:4000/#!some/path?foo=1&bar=2#some_fragment"
  """
  @spec to_string(URI.t()) :: String.t()
  def to_string(uri) do
    if not is_nil(uri.path) and not String.starts_with?(uri.path, "/"),
      do: raise(ArgumentError, message: "the input path must start with /")

    URI.to_string(%URI{uri | path: "/", query: nil, fragment: encode_fragment(uri)})
  end

  @doc """
  Parses a well-formed VBT URI string into its components.

      iex> VbtURI.parse("http://foo.bar:4000/#!some/path?foo=1&bar=2#some_fragment")
      %URI{
        scheme: "http",
        host: "foo.bar",
        port: 4000,
        path: "/some/path",
        query: "foo=1&bar=2",
        fragment: "some_fragment",
        userinfo: nil,
        authority: "foo.bar:4000",
      }

  If the input is not a valid VBT URI, this function will raise an argument error.
  """
  @spec parse(String.t()) :: URI.t()
  def parse(uri_string) do
    standard_uri = URI.parse(uri_string)

    if standard_uri.path != "/" or standard_uri.query != nil or
         not String.starts_with?(standard_uri.fragment || "", "!"),
       do: raise(ArgumentError, message: "invalid uri")

    vbt_uri = decode_fragment(standard_uri.fragment)

    %URI{
      scheme: standard_uri.scheme,
      userinfo: standard_uri.userinfo,
      host: standard_uri.host,
      port: standard_uri.port,
      authority: standard_uri.authority,
      path: vbt_uri.path,
      query: vbt_uri.query,
      fragment: vbt_uri.fragment
    }
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp encode_fragment(uri) do
    path = encode_path(uri.path)
    "!" <> URI.to_string(%URI{path: path, query: uri.query, fragment: uri.fragment})
  end

  defp encode_path(nil), do: nil
  defp encode_path("/" <> path), do: path

  defp decode_fragment("!" <> fragment) do
    %URI{path: path, query: query, fragment: fragment} = URI.parse(fragment)
    %URI{path: decode_path(path), query: query, fragment: fragment}
  end

  defp decode_path(nil), do: nil
  defp decode_path(path), do: "/#{path}"
end
