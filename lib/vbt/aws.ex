defmodule VBT.Aws do
  @moduledoc "Helper module for working with AWS."

  @type response ::
          {:ok,
           %{
             required(:body) => String.t(),
             required(:headers) => [{String.t(), String.t()}],
             optional(:status_code) => pos_integer()
           }}
          | {:error, reason :: any}

  @doc """
  Returns AWS client module.

  Invoke this function when making AWS requests to obtain the AWS module which implements
  `ExAws.Behaviour`. For example, to make a request:

      VBT.Aws.client().request(ExAws.S3.list_buckets(), region: "eu-west-1")

  By default, this function returns `ExAws`. However, you can change the module globally via
  the `:ex_aws_client` configuration of the `:vbt` app. This should typically be done only in
  test environment to use a mock defined via `Mox`. If you generated your project via the latest
  skafolder, the mock module named `VBT.TestAwsClient` will already be configured.
  """
  @spec client() :: module()
  def client, do: Application.get_env(:vbt, :ex_aws_client, ExAws)
end
