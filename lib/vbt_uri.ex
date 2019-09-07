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

  @spec to_string(URI.t()) :: String.t()
  def to_string(uri) do
    if not is_nil(uri.path) and String.starts_with?(uri.path, "/"),
      do: raise(ArgumentError, message: "the input path must not start with /")

    URI.to_string(%URI{uri | path: "/", query: nil, fragment: encode_fragment(uri)})
  end

  @spec parse(String.t()) :: URI.t()
  def parse(uri_string) do
    uri = URI.parse(uri_string)

    if uri.path != "/" or uri.query != nil or not String.starts_with?(uri.fragment || "", "!"),
      do: raise(ArgumentError, message: "invalid uri")

    %URI{scheme: scheme, host: host, port: port, fragment: fragment} = uri
    %URI{path: path, query: query, fragment: fragment} = decode_fragment(fragment)
    %URI{scheme: scheme, host: host, port: port, path: path, query: query, fragment: fragment}
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp encode_fragment(uri),
    do: "!" <> URI.to_string(%URI{path: uri.path, query: uri.query, fragment: uri.fragment})

  defp decode_fragment("!" <> fragment) do
    %URI{path: path, query: query, fragment: fragment} = URI.parse(fragment)
    %URI{path: path, query: query, fragment: fragment}
  end
end
