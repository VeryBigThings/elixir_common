defmodule VBT.Absinthe.ResolverHelper do
  @moduledoc deprecated: "Use VBT.Absinthe.Schema instead."

  alias VBT.Absinthe.Schema.NormalizeErrors

  # TODO: hard-deprecate with `@deprecated` in the next version.
  @doc deprecated: "Use VBT.Absinthe.Schema instead."
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def changeset_errors(changeset, opts \\ []),
    do: NormalizeErrors.changeset_errors(changeset, opts)
end
