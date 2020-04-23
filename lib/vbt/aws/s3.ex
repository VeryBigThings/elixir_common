defmodule VBT.Aws.S3 do
  @moduledoc """
  Helper for performing actions on S3.

  When making requests to S3, the `VBT.Aws.client/0` function is invoked to determine the actual
  client module. Consequently, you can mock this module in tests with `Mox`.
  """

  @type config :: %{
          scheme: String.t(),
          host: String.t(),
          region: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t()
        }

  @type upload_source :: binary | {:file, Path.t()} | Enumerable.t()

  defprotocol Hostable do
    @moduledoc """
    Protocol for objects which can be hosted on S3.

    By default this protocol is implemented for strings, where a string represents the path in the
    bucket where the object resides. Additionally, you can implement the protocol for your custom
    structs.
    """

    @doc "Invoked to return the asset path."
    @spec path(t) :: String.t()
    def path(object)
  end

  defimpl Hostable, for: BitString do
    def path(string) when is_binary(string), do: string
    def path(_bitstring), do: raise("bitstring isn't a valid path")
  end

  @doc "Returns the presigned upload url for the given object."
  @spec upload_url(config, String.t(), Hostable.t()) :: String.t()
  def upload_url(config, bucket, object) do
    {:ok, url} = ExAws.S3.presigned_url(config, :put, bucket, Hostable.path(object))
    url
  end

  @doc "Downloads the given object from S3."
  @spec download(config, String.t(), Hostable.t()) :: VBT.Aws.response()
  def download(config, bucket, object) do
    bucket
    |> ExAws.S3.get_object(Hostable.path(object))
    |> VBT.Aws.client().request(config)
  end

  @doc """
  Uploads the source to the path of the given target (hostable object).

  Source can be one of the following:

    - `{:file, String.t}` - path to a local file to upload
    - `binary` - content to upload
    - enumerable of binaries - chunks of data to upload

  The content is uploaded in chunks of 5 MiB. Notice that if you pass an enumerable of binaries,
  the input chunks won't affect the upload chunks.
  """
  @spec upload(config, String.t(), upload_source, Hostable.t()) :: VBT.Aws.response()
  def upload(config, bucket, source, target) do
    source
    |> upload_chunks()
    |> ExAws.S3.upload(bucket, Hostable.path(target))
    |> VBT.Aws.client().request(config)
  end

  defp upload_chunks({:file, path}), do: File.stream!(path, [], chunk_size())
  defp upload_chunks(content) when is_binary(content), do: upload_chunks([content])

  defp upload_chunks(binaries) do
    binaries
    |> Stream.flat_map(&:binary.bin_to_list/1)
    |> Stream.chunk_every(chunk_size())
    |> Stream.map(&:erlang.list_to_binary/1)
  end

  @doc false
  def chunk_size,
    # The required chunk size for S3 upload is 5 MiB.
    # We're using a smaller chunk in test to reduce the test time.
    do: unquote(if Mix.env() == :test, do: 100, else: 5 * 1024 * 1024)
end
