# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule VBT.TestAsset do
  @moduledoc false
  defstruct path: nil

  def new(path), do: %__MODULE__{path: path}

  defimpl VBT.Aws.S3.Hostable do
    def path(test_struct), do: test_struct.path
  end
end
