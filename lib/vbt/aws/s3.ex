defmodule VBT.Aws.S3 do
  @moduledoc """
  Helper for performing actions on S3.

  When making requests to S3, the `VBT.Aws.client/0` function is invoked to determine the actual
  client module. Consequently, you can use `VBT.Aws.Test` to test this module.
  """

  @type config :: %{
          scheme: String.t(),
          host: String.t(),
          region: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t()
        }

  @type upload_source :: binary | {:file, Path.t()} | Enumerable.t()

  @type s3_response :: %{
          required(:body) => String.t(),
          required(:headers) => [{String.t(), String.t()}],
          optional(:status_code) => pos_integer()
        }

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

  @doc "Returns the presigned download url for the given object."
  @spec download_url(config, String.t(), Hostable.t()) :: String.t()
  def download_url(config, bucket, object),
    do: presigned_url(config, :get, bucket, Hostable.path(object))

  @doc "Returns the presigned upload url for the given object."
  @spec upload_url(config, String.t(), Hostable.t()) :: String.t()
  def upload_url(config, bucket, object),
    do: presigned_url(config, :put, bucket, Hostable.path(object))

  @doc "Downloads the given object from S3."
  @spec download(config, String.t(), Hostable.t()) :: VBT.Aws.response(s3_response)
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

  ## Testing

  To test this function, you can use `VBT.Aws.Test`:

      test "upload" do
        Aws.Test.stub_request("")

        assert S3.upload(config, bucket, content, target) == {:ok, ""}

        path = S3.Hostable.path(target)
        assert_received {:aws_request, %ExAws.S3.Upload{bucket: ^bucket, path: ^path} = req, _}
        chunks = Enum.to_list(req.src)
        uploaded_content = IO.iodata_to_binary(chunks)

        # make assertions on uploaded_content
      end

  Note: `opts` are any options accepted by `ExAws.S3.upload/4`. This should correspond to
  `t:ExAws.S3.upload_opts/0`. However, this type is slightly incorrect, and using it leads to
  dialyzer errors, so the spec of this function uses a more relaxed `Keyword.t`.
  """
  @spec upload(config, String.t(), upload_source, Hostable.t(), Keyword.t()) ::
          VBT.Aws.response(s3_response)
  def upload(config, bucket, source, target, opts \\ []) do
    source
    |> upload_chunks()
    |> ExAws.S3.upload(bucket, Hostable.path(target), opts)
    |> VBT.Aws.client().request(config)
  end

  defp presigned_url(config, method, bucket, object) do
    {:ok, url} = ExAws.S3.presigned_url(config, method, bucket, object)
    url
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
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def chunk_size,
    # The required chunk size for S3 upload is 5 MiB.
    # We're using a smaller chunk in test to reduce the test time.
    do: unquote(if Mix.env() == :test, do: 100, else: 5 * 1024 * 1024)
end
