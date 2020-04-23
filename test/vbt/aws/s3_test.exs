defmodule VBT.Aws.S3Test do
  use ExUnit.Case, async: true
  import VBT.TestHelper
  alias VBT.Aws.S3
  alias VBT.TestAsset

  describe "upload_url" do
    test "includes bucket and path in the result" do
      url = S3.upload_url(config(), "some_bucket", "/some/path")
      assert url =~ "some_bucket"
      assert url =~ "/some/path"
    end

    test "accepts a hostable for path" do
      url = S3.upload_url(config(), "some_bucket", TestAsset.new("/another/path"))
      assert url =~ "/another/path"
    end
  end

  describe "download" do
    test "makes an S3 get request" do
      response = %{body: "content", headers: [], status_code: 200}

      Mox.expect(VBT.aws_client(), :request, fn req, config ->
        assert config == config()

        assert req.http_method == :get
        assert req.bucket == "some bucket"
        assert req.path == "/some/path"

        response
      end)

      assert S3.download(config(), "some bucket", "/some/path") == response
    end

    test "accepts a hostable for path" do
      response = %{body: "content", headers: [], status_code: 200}

      Mox.expect(VBT.aws_client(), :request, fn req, _config ->
        assert req.path == "/another/path"
        response
      end)

      assert S3.download(config(), "some bucket", TestAsset.new("/another/path")) == response
    end
  end

  describe "upload" do
    test "uploads a small binary as a single chunk" do
      assert upload("some content") == ["some content"]
    end

    test "uploads a large binary in multiple chunks" do
      bytes = :crypto.strong_rand_bytes(S3.chunk_size() + 1)
      assert [chunk1, chunk2] = upload(bytes)
      assert chunk1 <> chunk2 == bytes
      assert byte_size(chunk2) == 1
    end

    test "uploads a small stream of binaries as a single chunk" do
      binaries = Stream.map(1..10, &to_string/1)
      assert upload(binaries) == [to_string(Enum.to_list(binaries))]
    end

    test "uploads a large stream of binaries in multiple chunks" do
      binaries = Stream.take(Stream.repeatedly(fn -> "A" end), S3.chunk_size() + 1)
      assert [chunk1, chunk2] = upload(binaries)
      assert chunk1 <> chunk2 == to_string(Enum.to_list(binaries))
      assert byte_size(chunk2) == 1
    end

    test "uploads a small file as a single chunk" do
      path = Path.join(System.tmp_dir!(), "temp_file_#{unique_positive_integer()}")

      try do
        File.write!(path, "some content")
        assert upload({:file, path}) == ["some content"]
      after
        File.rm(path)
      end
    end

    test "uploads a large file in multiple chunks" do
      path = Path.join(System.tmp_dir!(), "temp_file_#{unique_positive_integer()}")

      try do
        bytes = :crypto.strong_rand_bytes(S3.chunk_size() + 1)
        File.write!(path, bytes)
        assert [chunk1, chunk2] = upload({:file, path})
        assert chunk1 <> chunk2 == bytes
        assert byte_size(chunk2) == 1
      after
        File.rm(path)
      end
    end

    defp upload(content, opts \\ []) do
      bucket = Keyword.get(opts, :bucket, "some bucket")
      target = Keyword.get(opts, :target, "/some/path")
      test_pid = self()

      Mox.expect(VBT.aws_client(), :request, fn req, config ->
        assert config == config()

        assert %ExAws.S3.Upload{} = req
        assert req.bucket == bucket
        assert req.path == S3.Hostable.path(target)

        send(test_pid, {:chunks, Enum.to_list(req.src)})
      end)

      S3.upload(config(), bucket, content, target)

      assert_receive {:chunks, chunks}
      chunks
    end
  end

  defp config do
    %{
      scheme: "https://",
      host: "s3.amazonaws.com",
      region: "us-east-1",
      access_key_id: "access_key",
      secret_access_key: "secret_access_key"
    }
  end
end
