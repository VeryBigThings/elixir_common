defmodule VBT.Absinthe.ResolverHelper do
  @moduledoc deprecated: "Use VBT.Absinthe.Schema instead."

  # TODO: hard-deprecate with `@deprecated` in the next version.
  @doc deprecated: "Use VBT.Absinthe.Schema instead."
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  defdelegate changeset_errors(changeset, opts \\ []), to: VBT.Absinthe.Schema.NormalizeErrors
end
