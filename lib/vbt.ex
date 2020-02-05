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
  test environment to use a mock defined via `Mox`.
  """
  @spec aws_client() :: module()
  def aws_client, do: Application.get_env(:vbt, :ex_aws_client, ExAws)
end
