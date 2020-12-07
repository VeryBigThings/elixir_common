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

    test "returns validation errors as changeset" do
      assert {:error, changeset} =
               Validation.normalize(
                 %{"foo" => "invalid value"},
                 foo: :integer,
                 bar: {:string, required: true}
               )

      refute changeset.valid?
      assert changeset.action == :insert

      assert {"is invalid", _} = changeset.errors[:foo]
      assert {"can't be blank", _} = changeset.errors[:bar]
    end
  end

  describe "changeset" do
    test "returns the changeset with the changes" do
      changeset = Validation.changeset(%{"foo" => "1"}, foo: :string)
      assert Ecto.Changeset.apply_changes(changeset) == %{foo: "1"}
    end

    test "returns the changeset with errors" do
      changeset =
        Validation.changeset(
          %{"foo" => "invalid value"},
          foo: :integer,
          bar: {:string, required: true}
        )

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:foo]
      assert {"can't be blank", _} = changeset.errors[:bar]
    end
  end
end
