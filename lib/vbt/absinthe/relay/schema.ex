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

  ## Mutation resolvers

  Most of the functionality in this module and a few other supporting modules serves to simplify
  the implementation of standard VBT mutation resolvers.

  A standard VBT mutation resolver has the following properties:

  1. It is a Relay modern payload field.
  2. The single field of the output is called `:result`.
  3. Business errors are returned as success results, using union to distinguish between business
     success and error.

  ### Business errors

  A business error is any error that should be presented to the user. For example, consider a
  simple `register` mutation with two input fields, login and password. This operation can result
  in the following errors:

  1. Login is an empty string
  2. Password is an empty string
  3. Login is already taken

  In most scenarios, we'll only consider the 3rd error as a reportable error, leaving it to frontend
  to detect and report the remaining ones before they make a backend request. We still have to
  fully validate the data on the backend side, checking for all possible errors, but we'll only
  return the last one as a business error, while the remaining ones will be returned as standard
  GraphQL errors.

  Here's the recipe for creating a corresponding mutation:

  1. Create a context function with the following specification:

          defmodule MyContext do
            # This context function should return `{:error, VBT.BusinessError.t}` only if the login
            # is already taken. All other errors should be returned through a changeset, or custom
            # error strings.
            @spec register(String.t, String.t) ::
              {:ok, User.t}
              | {:error, VBT.BusinessError.t}
              | {:error, Ecto.Changeset.t}
              | {:error, String.t}

            # ...
          end

  2. Create a resolver function:

          def register(input, _resolution),
            do: MyContext.register(input.login, input.password)

  3. Use a union type for the mutation:

          mutation do
            payload field :register do
              # ...

              output do
                field :result, payload_type(:result)

                union payload_type(:result) do
                  types [:user, :business_error]
                  resolve_type fn result, _ -> error_type(result) || :user end
                end
              end

              resolve payload_resolver(&register/2)
            end
          end

    See `output/2` and `payload_resolver/1` docs for more details.

  ### Custom business errors

  Most business errors should be reported as `VBT.BusinessError`, using either an error code as
  arranged with the frontend team. Occasionally, you might need to add a specific kind of error
  which contains additional fields. In such situations, you can do the following:

  1. Define a custom error in the context namespace using `VBT.Error`.

  2. Return the custom error from the business operation.

  3. Adapt `resolve_type` as follows:

          resolve_type fn result, _ ->
            error_type(result) || case do
              %MyCustomError{} -> :my_custom_error
              _ -> :my_success_type
            end
          end

    If some custom errors are being used in multiple fields, you can reduce the duplication with a
    following helper private function in the schema module:

          defp business_error_type(result) do
            error_type(result) || case do
              %MyCustomError{} -> :my_custom_error
              _ -> nil
            end
          end

    And now `resolve_type` function can be condensed to `business_error_type(result) || :my_success_type`.
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
