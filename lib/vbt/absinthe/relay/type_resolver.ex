defmodule VBT.Absinthe.Relay.TypeResolver do
  @moduledoc """
  Helper for defining mappings between Relay types and modules (typically Ecto schemas).

      iex> defmodule MyProjectWeb.ResolverHelper do
      ...>   use VBT.Absinthe.Relay.TypeResolver, %{
      ...>     MyProject.Schemas => %{
      ...>       User => :user,
      ...>       Organization => :organization
      ...>     }
      ...>   }
      ...> end
      iex> MyProjectWeb.ResolverHelper.module(:user)
      MyProject.Schemas.User
      iex> MyProjectWeb.ResolverHelper.type(MyProject.Schemas.User)
      :user
  """

  @doc false
  defmacro __using__(definition) do
    quote bind_quoted: [definition: definition] do
      for {scope, mappings} <- definition,
          {module, type} <- mappings do
        module = Module.concat(scope, module)

        @doc "Returns the module for the given type."
        @spec module(unquote(type)) :: unquote(module)
        def module(unquote(type)), do: unquote(module)

        @doc "Returns the type for the given module."
        @spec type(unquote(module)) :: unquote(type)
        def type(unquote(module)), do: unquote(type)
      end
    end
  end
end
