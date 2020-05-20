defmodule VBT.Aws.Test do
  @moduledoc """
  Helpers for testing AWS interaction.

  ## Usage

      # test_helper.exs
      VBT.Aws.Test.setup()

      # some_test.exs
      test "..." do
        VBT.Aws.Test.stub_request(response)

        assert perform_aws_operation(...) == {:ok, response}

        assert_received {:aws_request, req, config}
        # do something with req and config
      end
  """

  @doc """
  Sets up test mock which implements `ExAws.Behaviour`.

  Invoke this function in test_helper.exs to setup the mock. Then, in your tests you can use
  `stub_request/1`. If you need a finer grained control, you can also use `Mox`. See
  `stub_request/1` for details.
  """
  @spec setup :: :ok
  def setup do
    Application.put_env(:vbt, :ex_aws_client, VBT.TestAwsClient)
    Mox.defmock(VBT.TestAwsClient, for: ExAws.Behaviour)
    :ok
  end

  @doc """
  Stubs the `:request` function of the module returned by `VBT.Aws.client/0`.

  The `response` argument can be either `t:VBT.Aws.response/0`, which represents the response
  of the operation, or a binary, in which case the response will be
  `{:ok, %{body: response, headers: [], status_code: 200}}`.

  This function will also send a message in the shape of `{:aws_request, req, config}` to
  the caller process. Therefore, you can use `ExUnit.Assertions.assert_receive/3` to retrieve the
  request, and make further assertions. Note that this will only work if `assert_receive/3` is
  invoked in the same process as `stub_request/0`. Consequently, this approach will work if
  this function is invoked from `test`, or `setup` blocks, but not from `setup_all`.

  This function is a lightweight wrapper around `Mox`. If you need more control, you can mock
  AWS client directly as follows:

      Mox.stub(VBT.Aws.client(), :request, fn req, config -> ... end)
  """
  @spec stub_request(VBT.Aws.response() | binary) :: :ok
  def stub_request(response) do
    test_pid = self()

    Mox.stub(VBT.TestAwsClient, :request, fn req, config ->
      send(test_pid, {:aws_request, req, config})

      case response do
        body when is_binary(body) -> {:ok, %{body: body, headers: [], status_code: 200}}
        {:ok, _} = success -> success
        {:error, _} = error -> error
      end
    end)

    :ok
  end
end
