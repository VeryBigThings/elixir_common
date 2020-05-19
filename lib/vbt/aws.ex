defmodule VBT.Aws do
  @moduledoc """
  Helper module for working with AWS.

  This module together with other `VBT.Aws.*` modules provide various helper functions for working
  with AWS. These modules are wrappers around `ExAws`.

  If you need to directly interact with AWS, feel free to use `ExAws` function. For simplified
  testing, instead of directly invoking `ExAws` functions, use the `client/0` function from this
  module to obtain the implementation of `ExAws.Behaviour`. See `VBT.Aws.Test` for details.
  """

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

  Invoke this function when making AWS requests to obtain the module which implements
  `ExAws.Behaviour`. For example, to make a request:

      VBT.Aws.client().request(ExAws.S3.list_buckets(), region: "eu-west-1")

  By default, this function returns `ExAws`. In tests, you can setup a mock module using the
  `VBT.Aws.Test` module.
  """
  @spec client() :: module()
  def client, do: Application.get_env(:vbt, :ex_aws_client, ExAws)
end
