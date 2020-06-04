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

  @doc """
  Resolves the GraphQL type of a VBT business error, or returns `nil` if the provided argument is
  not a known VBT business error.

  This function can be useful when resolving union types. For example:

      union :login_result do
        types [:login_, :business_error]
        resolve_type fn result, _ -> error_type(result) || :login end
      end
  """
  @spec error_type(any) :: :business_error | nil
  def error_type(%VBT.BusinessError{}), do: :business_error
  def error_type(_unknown), do: nil

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema
      import unquote(__MODULE__)

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
