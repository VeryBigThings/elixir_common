defmodule VBT do
  @moduledoc "Common helper functions"

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Returns AWS client module.

  Invoke this function when making AWS requests to obtain the AWS module which implements
  `ExAws.Behaviour`. For example, to make a request:

      VBT.aws_client().request(ExAws.S3.list_buckets(), region: "eu-west-1")

  By default, this function returns `ExAws`. However, you can change the module globally via
  the `:ex_aws_client` configuration of the `:vbt` app. This should typically be done only in
  test environment to use a mock defined via `Mox`. If you generated your project via the latest
  skafolder, the mock module named `VBT.TestAwsClient` will be already configured.
  """
  @spec aws_client() :: module()
  def aws_client, do: Application.get_env(:vbt, :ex_aws_client, ExAws)

  @doc "Converts a boolean into `:ok | {:error, reason}`."
  @spec validate(boolean, error) :: :ok | {:error, error} when error: var
  def validate(condition, error), do: if(condition, do: :ok, else: {:error, error})

  @doc "Converts a boolean into `:ok | {:error, :unauthorized}`."
  @spec authorize(boolean) :: :ok | {:error, :unauthorized}
  def authorize(condition), do: validate(condition, :unauthorized)
end
