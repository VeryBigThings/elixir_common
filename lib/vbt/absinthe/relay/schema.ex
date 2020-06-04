defmodule VBT.Absinthe.Relay.Schema do
  @moduledoc """
  Helper for building modern flavour Relay schemas.

  Use this module in place of `use Absinthe.Schema` and `use Absinthe.Relay.Schema` in your schema
  modules. When used, the following extensions are brought to the client module:

  1. `use VBT.Absinthe.Schema`
  2. `use Absinthe.Relay.Schema, flavor: :modern`
  3. A custom version of `output/2` (see macro docs for more detail).

  You can provide options to `Absinthe.Relay.Schema`, by passing them to when using this module:

      use VBT.Absinthe.Schema,
        global_id_translator: Absinthe.Relay.Node.IDTranslator.Base64

  You don't need to pass the `:flavor` option. It will be always set to `:modern`, and this can't
  be changed.
  """

  @type resolver :: resolver_arity_2 | resolver_arity_3
  @type resolver_arity_2 :: (any, Absinthe.Resolution.t() -> resolver_result)
  @type resolver_arity_3 :: (map, any, Absinthe.Resolution.t() -> resolver_result)
  @type resolver_result :: {:ok, any} | {:error, any}

  @doc """
  Defines the output (payload) type for the payload field.

  This macro is a modification of `Absinthe.Relay.Mutation.Notation.Modern.output/2` which
  supports defining object and union types inside the output block.

  Example:

      payload field :login do
        # ...

        output do
          field :result, :result

          union :result do
            types [:success, :error]
            # ...
          end

          object :success do
            # ...
          end

          object :error do
            # ...
          end
        end

        # ...
      end

  Note that the types declared inside the output are still global, which means that you can't
  declare the type of the same name (e.g. `:result`) in more than one field.

  To simplify name scoping, a special syntax `payload_type(type_name)` is supported, which will
  be expanded into `:"\#{field_name}_payload_\#{type_name}"`.

  Example:

      payload field :login do
        # ...

        output do
          field :result, payload_type(:result)

          union payload_type(:result) do
            types [payload_type(:success), payload_type(:error)]
            # ...
          end

          resolve_type fn
            %{login: _, token: _} -> payload_type(:success)
            %{error_code: _} -> payload_type(:error)
          end

          object payload_type(:success) do
            # ...
          end

          object payload_type(:error) do
            # ...
          end
        end

        # ...
      end

  The type names will be `login_payload_result`, `login_payload_success`, and `login_payload_error`.
  The usage of `payload_type` is optional, and you can combine it with plain type references:

      payload field :login do
        # ...

        output do
          field :result, payload_type(:result)

          # The `:success` type name is decorated, while `:business_error` is not.
          union payload_type(:result) do
            types [payload_type(:success), :business_error]
            # ...
          end

          # ...
        end

        # ...
      end
  """
  defmacro output(identifier, do: block) do
    # modify do/end AST of the output expression
    block =
      Macro.postwalk(block, fn
        {:payload_type, _meta, [name]} ->
          :"#{identifier}_#{name}"

        {type, _meta, _args} = typedef when type in ~w/object union/a ->
          # decorate every object and union expression in the output block
          quote do
            # temporarily set the context to the schema root
            Absinthe.Schema.Notation.stash()

            # inject the expression
            unquote(typedef)

            # restore the context
            Absinthe.Schema.Notation.pop()
          end

        node ->
          node
      end)

    # forward to absinthe's output expression
    Absinthe.Relay.Schema.Notation.output(
      Absinthe.Relay.Mutation.Notation.Modern,
      identifier,
      block
    )
  end

  @doc """
  Creates a VBT standard resolver of a mutation payload field.

  This function converts a plain absinthe resolver into a VBT standard resolver. The new resolver
  has the following behaviour:

  1. A successful result (`{:ok, result}`) will be converted into `%{:ok, %{result: result}}`
  2. A business error (`{:error, business_error}`, where `business_error` is a struct created with
     `VBT.Error`), will be converted into `{:ok, %{result: business_error}}`.
  3. All other error are propagated as errors.
  4. An error is raised for any other kind of result.

  Usage:

      mutation do
        payload field :some_field do
          # ...

          output do
            # ...

            resolve payload_resolver(fn arg, resolution ->
                              # resolve and return
                              #   {:ok, result}
                              #   | {:error, business_error}
                              #   | {:error, non_business_error}
                            end)
          end
        end
      end


  You can also pass a 3-arity function.
  """
  @spec payload_resolver(resolver) :: resolver_arity_3
  def payload_resolver(resolver) when is_function(resolver, 2),
    do: payload_resolver(fn _, arg, resolution -> resolver.(arg, resolution) end)

  def payload_resolver(resolver) when is_function(resolver, 3) do
    fn parent, arg, resolution ->
      case resolver.(parent, arg, resolution) do
        {:ok, result} -> {:ok, %{result: result}}
        {:error, %{__vbt_error__: true} = business_error} -> {:ok, %{result: business_error}}
        {:error, _} = error -> error
      end
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote do
      use VBT.Absinthe.Schema
      use Absinthe.Relay.Schema, unquote(Keyword.put(opts, :flavor, :modern))
      import Absinthe.Relay.Mutation.Notation.Modern, except: [output: 2]
      import unquote(__MODULE__)
    end
  end
end
