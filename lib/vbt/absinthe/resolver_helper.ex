defmodule VBT.Absinthe.ResolverHelper do
  # TODO: remove in the next version.
  @moduledoc deprecated: "Use VBT.Absinthe.Schema instead."

  alias VBT.Absinthe.Schema.NormalizeErrors

  # TODO: remove in the next version.
  @deprecated "Use VBT.Absinthe.Schema instead."
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def changeset_errors(changeset, opts \\ []),
    do: NormalizeErrors.changeset_errors(changeset, opts)
end
