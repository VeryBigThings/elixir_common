defmodule VBT.ValidationTest do
  use ExUnit.Case, async: true
  doctest VBT.Validation

  alias VBT.Validation

  describe "normalize" do
    test "normalizes key to atom" do
      assert Validation.normalize(%{"foo" => "1"}, foo: :string) == {:ok, %{foo: "1"}}
    end

    test "discards unknown keys" do
      assert Validation.normalize(%{"foo" => "1", "bar" => "2"}, foo: :string) ==
               {:ok, %{foo: "1"}}
    end

    test "converts boolean" do
      assert Validation.normalize(%{"foo" => "true"}, foo: :boolean) == {:ok, %{foo: true}}
    end

    test "converts integer" do
      assert Validation.normalize(%{"foo" => "1"}, foo: :integer) == {:ok, %{foo: 1}}
    end

    test "converts float" do
      assert Validation.normalize(%{"foo" => "3.14"}, foo: :float) == {:ok, %{foo: 3.14}}
    end

    test "converts date" do
      assert Validation.normalize(%{"foo" => "2020-01-31"}, foo: :date) ==
               {:ok, %{foo: ~D[2020-01-31]}}
    end

    test "converts time" do
      assert Validation.normalize(%{"foo" => "01:02:03"}, foo: :time) ==
               {:ok, %{foo: ~T[01:02:03]}}
    end

    test "converts date time" do
      assert Validation.normalize(%{"foo" => "2020-01-31 01:02:03"}, foo: :utc_datetime) ==
               {:ok, %{foo: ~U[2020-01-31 01:02:03Z]}}
    end

    test "supports enum" do
      assert Validation.normalize(%{"foo" => "bar"}, foo: {:enum, ~w/bar baz/a}) ==
               {:ok, %{foo: :bar}}
    end

    test "supports arrays" do
      assert Validation.normalize(
               %{"foo" => ["bar", "baz"]},
               foo: {:array, {:enum, ~w/bar baz/a}}
             ) == {:ok, %{foo: [:bar, :baz]}}
    end

    test "returns validation errors as changeset" do
      assert {:error, changeset} =
               Validation.normalize(
                 %{"foo" => "invalid value"},
                 foo: :integer,
                 bar: {:string, required: true}
               )

      refute changeset.valid?
      assert changeset.action == :insert

      assert "is invalid" in field_errors(changeset, :foo)
      assert "can't be blank" in field_errors(changeset, :bar)
    end

    test "supports custom validation" do
      assert {:error, changeset} =
               Validation.normalize(
                 %{"password" => "abc", "password_confirmation" => "def"},
                 [password: :string],
                 validate: &Ecto.Changeset.validate_confirmation(&1, :password, required: true)
               )

      assert "does not match confirmation" in field_errors(changeset, :password_confirmation)
    end

    test "supports has_one-like assoc" do
      order_item_spec = [product_id: :integer, quantity: :integer]
      order_spec = [user_id: :integer, order_item: order_item_spec]

      data = %{
        "user_id" => "1",
        "order_item" => %{"product_id" => "2", "quantity" => "3"}
      }

      assert {:ok, normalized} = Validation.normalize(data, order_spec)
      assert normalized == %{user_id: 1, order_item: %{product_id: 2, quantity: 3}}
    end

    test "returns errors from has_one-like assoc" do
      order_item_spec = [
        product_id: {:integer, required: true},
        quantity: {:integer, required: true}
      ]

      order_spec = [user_id: :integer, order_item: order_item_spec]

      data = %{"user_id" => "1", "order_item" => %{}}

      assert {:error, changeset} = Validation.normalize(data, order_spec)
      assert "product_id can't be blank" in field_errors(changeset, :order_item)
      assert "quantity can't be blank" in field_errors(changeset, :order_item)
    end

    test "validates required has_one-like assoc" do
      order_item_spec = [product_id: :integer, quantity: :integer]
      order_spec = [user_id: :integer, order_item: {order_item_spec, required: true}]

      data = %{"user_id" => "1"}

      assert {:error, changeset} = Validation.normalize(data, order_spec)
      assert "can't be blank" in field_errors(changeset, :order_item)
    end

    test "supports has_many-like assoc" do
      order_item_spec = [product_id: :integer, quantity: :integer]
      order_spec = [user_id: :integer, order_items: {:array, order_item_spec}]

      data = %{
        "user_id" => "1",
        "order_items" => [
          %{"product_id" => "2", "quantity" => "3"},
          %{"product_id" => "4", "quantity" => "5"}
        ]
      }

      assert {:ok, normalized} = Validation.normalize(data, order_spec)

      assert normalized == %{
               user_id: 1,
               order_items: [%{product_id: 2, quantity: 3}, %{product_id: 4, quantity: 5}]
             }
    end

    test "returns errors from has_many-like assoc" do
      order_item_spec = [
        product_id: {:integer, required: true},
        quantity: {:integer, required: true}
      ]

      order_spec = [user_id: :integer, order_items: {:array, order_item_spec}]

      data = %{"user_id" => "1", "order_items" => [%{}, %{}]}

      assert {:error, changeset} = Validation.normalize(data, order_spec)
      assert "[0] product_id can't be blank" in field_errors(changeset, :order_items)
      assert "[1] product_id can't be blank" in field_errors(changeset, :order_items)

      assert "[0] quantity can't be blank" in field_errors(changeset, :order_items)
      assert "[1] quantity can't be blank" in field_errors(changeset, :order_items)
    end

    test "custom validation in a nested assoc" do
      user_spec = {
        [password: {:string, required: true}],
        validate: &Ecto.Changeset.validate_confirmation(&1, :password, required: true)
      }

      data = %{
        "users" => [
          %{"password" => "foo", "password_confirmation" => "foo"},
          %{"password" => "bar", "password_confirmation" => "baz"}
        ]
      }

      assert {:error, changeset} = Validation.normalize(data, users: {:array, user_spec})

      assert field_errors(changeset, :users) ==
               ["[1] password_confirmation does not match confirmation"]
    end
  end

  defp field_errors(changeset, field),
    do: Enum.map(Keyword.get_values(changeset.errors, field), fn {error, _} -> error end)
end
