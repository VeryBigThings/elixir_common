defmodule VBT.Absinthe.Schema do
  @moduledoc """
  Helper for building GraphQL schemas.

  Use this module in place of `use Absinthe.Schema` in your schema modules. When used, the
  following extensions are brought to the client module:

  1. `use Absinthe.Schema`
  2. `import_types VBT.Graphql.Types`
  3. Installs the `VBT.Absinthe.Schema.NormalizeErrors` middleware to each field with a declared
     resolver.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema

      # Conditionally defining the behaviour to support absinthe 1.4 and 1.5
      unless Enum.member?(Module.get_attribute(__MODULE__, :behaviour), Absinthe.Schema),
        do: @behaviour(Absinthe.Schema)

      import_types VBT.Graphql.Types

      @impl Absinthe.Schema
      def middleware(middlewares, _field, _object) do
        # We'll only add the normalizer middleware to the fields with a declared resolver.
        if Enum.any?(middlewares, &match?({{Absinthe.Resolution, :call}, _}, &1)),
          do: middlewares ++ [VBT.Absinthe.Schema.NormalizeErrors],
          else: middlewares
      end

      # allows clients to override the global schema middleware setup
      @defoverridable [middleware: 3]
    end
  end
end
