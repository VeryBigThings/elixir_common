defmodule VBT.Absinthe.SchemaTest do
  use VBT.Graphql.Case, async: true, endpoint: __MODULE__.TestServer, api_path: "/"
  alias VBT.Absinthe.Schema.NormalizeErrors

  describe "resolver" do
    setup do
      Application.put_env(:vbt, __MODULE__.TestServer, [])
      start_supervised(__MODULE__.TestServer)
      :ok
    end

    test "handles the success result" do
      assert resolver_result({:ok, "some result"}) == {:ok, "some result"}
    end

    test "handles a string error" do
      assert {:error, response} = resolver_result({:error, "some error"})
      assert errors(response) == ["some error"]
    end

    test "handles a changeset error" do
      changeset =
        struct(__MODULE__.User)
        |> Ecto.Changeset.cast(%{age: "invalid"}, ~w/name age/a)
        |> Ecto.Changeset.validate_required(~w/name age/a)

      assert {:error, response} = resolver_result({:error, changeset})
      assert field_errors(response, "name") == ["can't be blank"]
      assert field_errors(response, "age") == ["is invalid"]
    end

    test "supports arity 3 function" do
      assert {:ok, %{resolver_3: result}} =
               call(
                 """
                 query($fun1: String!, $fun2: String!) {
                   resolver_3(fun: $fun1) {
                     value
                     child(fun: $fun2) {value}
                   }
                 }
                 """,
                 variables: %{
                   fun1:
                     encode(fn source, resolution ->
                       assert source == %{}
                       assert resolution.source == source
                       {:ok, %{value: "parent value", child: nil}}
                     end),
                   fun2:
                     encode(fn source, resolution ->
                       assert source == %{child: nil, value: "parent value"}
                       assert resolution.source == source
                       {:ok, %{value: "child value", child: nil}}
                     end)
                 }
               )

      assert result == %{value: "parent value", child: %{value: "child value"}}
    end

    test "supports {mod, fun}" do
      assert {:ok, %{resolver_mod_fun: result}} =
               call(
                 "query($fun: String!) {resolver_mod_fun(fun: $fun) {value}}",
                 variables: %{
                   fun:
                     encode(fn source, resolution ->
                       assert source == %{}
                       assert resolution.source == source
                       {:ok, %{value: "parent value", child: nil}}
                     end)
                 }
               )

      assert result == %{value: "parent value"}
    end

    defp resolver_result(result) do
      with {:ok, fields} <-
             call("query($fun: String!) {resolver_2(fun: $fun) {value}}",
               variables: %{
                 fun:
                   encode(fn _resolution ->
                     with {:ok, result} <- result, do: {:ok, %{value: result, child: nil}}
                   end)
               }
             ),
           do: {:ok, fields.resolver_2.value}
    end

    defp encode(fun), do: fun |> :erlang.term_to_binary() |> Base.encode64()
  end

  describe "changeset_errors" do
    defmodule Contact do
      use Ecto.Schema

      embedded_schema do
        field :phone_number, :string
      end
    end

    defmodule User do
      use Ecto.Schema

      embedded_schema do
        field :name, :string
        field :age, :integer

        has_many :contacts, VBT.Absinthe.SchemaTest.Contact
      end
    end

    defmodule Org do
      use Ecto.Schema

      embedded_schema do
        field :title, :string
        has_one :owner, VBT.Absinthe.SchemaTest.User
        has_many :users, VBT.Absinthe.SchemaTest.User
      end
    end

    test "reports errors" do
      errors =
        %User{}
        |> Ecto.Changeset.cast(%{age: "invalid"}, ~w/name age/a)
        |> Ecto.Changeset.validate_required(~w/name age/a)
        |> NormalizeErrors.changeset_errors()

      assert errors == [
               %{extensions: %{field: "age"}, message: "is invalid"},
               %{extensions: %{field: "name"}, message: "can't be blank"}
             ]
    end

    test "reports nested errors" do
      contact =
        %Contact{}
        |> Ecto.Changeset.cast(%{phone_number: "123"}, ~w/phone_number/a)
        |> Ecto.Changeset.validate_length(:phone_number, min: 10)

      owner =
        %User{contacts: []}
        |> Ecto.Changeset.cast(%{age: "invalid"}, ~w/age/a)
        |> Ecto.Changeset.put_assoc(:contacts, [contact, contact])

      user_changeset = Ecto.Changeset.cast(%User{contacts: []}, %{age: "invalid"}, ~w/age/a)

      errors =
        %Org{users: [], owner: nil}
        |> Ecto.Changeset.cast(%{}, ~w/title/a)
        |> Ecto.Changeset.validate_required(~w/title/a)
        |> Ecto.Changeset.put_assoc(:users, [user_changeset, user_changeset])
        |> Ecto.Changeset.put_assoc(:owner, owner)
        |> NormalizeErrors.changeset_errors()

      assert errors == [
               %{extensions: %{field: :age}, message: "is invalid"},
               %{
                 extensions: %{field: "phoneNumber"},
                 message: "should be at least 10 character(s)"
               },
               %{
                 extensions: %{field: "phoneNumber"},
                 message: "should be at least 10 character(s)"
               },
               %{extensions: %{field: "title"}, message: "can't be blank"},
               %{extensions: %{field: "age"}, message: "is invalid"},
               %{extensions: %{field: "age"}, message: "is invalid"}
             ]
    end

    test "formats error with key-value using the default formatter" do
      errors =
        %User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:name, "%{key1}", key1: "error1")
        |> NormalizeErrors.changeset_errors()

      assert errors == [%{extensions: %{field: "name"}, message: "error1"}]
    end

    test "formats error with key-value using the provided formatter" do
      errors =
        %User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:name, "%{key1}", key1: "error1")
        |> NormalizeErrors.changeset_errors(format_value: &"formatted #{&1} #{&2}")

      assert errors == [%{extensions: %{field: "name"}, message: "formatted key1 error1"}]
    end

    test "correctly handles unsafe_validate_unique error" do
      errors =
        %User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:name, "error", validation: :unsafe_unique, fields: [:name])
        |> NormalizeErrors.changeset_errors()

      assert errors == [%{extensions: %{field: "name"}, message: "error"}]
    end
  end

  defmodule TestServer do
    @moduledoc false

    use Phoenix.Endpoint, otp_app: :vbt

    plug Absinthe.Plug, schema: __MODULE__.Schema

    defmodule Schema do
      @moduledoc false
      use VBT.Absinthe.Schema

      query do
        field :resolver_2, :result do
          arg :fun, non_null(:string)
          resolve &resolver_2/2
        end

        field :resolver_3, :result do
          arg :fun, non_null(:string)
          resolve &resolver_3/3
        end

        field :resolver_mod_fun, :result do
          arg :fun, non_null(:string)
          resolve {__MODULE__, :resolver_mod_fun}
        end
      end

      object :result do
        field :value, non_null(:string)

        field :child, :result do
          arg :fun, non_null(:string)
          resolve &resolver_3/3
        end
      end

      defp resolver_2(arg, resolution) do
        fun(arg).(resolution)
      catch
        t, e ->
          {:error, Exception.format(t, e, __STACKTRACE__)}
      end

      defp resolver_3(source, arg, resolution) do
        fun(arg).(source, resolution)
      catch
        t, e ->
          {:error, Exception.format(t, e, __STACKTRACE__)}
      end

      @doc false
      # credo:disable-for-next-line Credo.Check.Readability.Specs
      def resolver_mod_fun(source, arg, resolution) do
        fun(arg).(source, resolution)
      catch
        t, e ->
          {:error, Exception.format(t, e, __STACKTRACE__)}
      end

      defp fun(arg), do: arg.fun |> Base.decode64!() |> :erlang.binary_to_term()
    end
  end
end
