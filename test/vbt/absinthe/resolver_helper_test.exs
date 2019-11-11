defmodule VBT.Absinthe.ResolverHelperTest do
  use ExUnit.Case, async: true
  alias VBT.Absinthe.ResolverHelper

  describe "changeset_errors" do
    defmodule User do
      use Ecto.Schema

      embedded_schema do
        field :name, :string
        field :age, :integer
      end
    end

    defmodule Org do
      use Ecto.Schema

      embedded_schema do
        field :title, :string
        has_many :users, VBT.Absinthe.ResolverHelperTest.User
      end
    end

    test "reports errors" do
      errors =
        %User{}
        |> Ecto.Changeset.cast(%{age: "invalid"}, ~w/name age/a)
        |> Ecto.Changeset.validate_required(~w/name age/a)
        |> ResolverHelper.changeset_errors()

      assert errors == [
               %{extensions: %{field: "age"}, message: "is invalid"},
               %{extensions: %{field: "name"}, message: "can't be blank"}
             ]
    end

    test "reports nested errors" do
      user_changeset = Ecto.Changeset.cast(%User{}, %{age: "invalid"}, ~w/age/a)

      errors =
        %Org{users: []}
        |> Ecto.Changeset.cast(%{}, ~w/title/a)
        |> Ecto.Changeset.validate_required(~w/title/a)
        |> Ecto.Changeset.put_assoc(:users, [user_changeset, user_changeset])
        |> ResolverHelper.changeset_errors()

      assert errors == [
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
        |> ResolverHelper.changeset_errors()

      assert errors == [%{extensions: %{field: "name"}, message: "error1"}]
    end

    test "formats error with key-value using the provided formatter" do
      errors =
        %User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:name, "%{key1}", key1: "error1")
        |> ResolverHelper.changeset_errors(format_value: &"formatted #{&1} #{&2}")

      assert errors == [%{extensions: %{field: "name"}, message: "formatted key1 error1"}]
    end
  end
end
