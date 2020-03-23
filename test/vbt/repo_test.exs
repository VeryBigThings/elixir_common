defmodule Vbt.RepoTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import VBT.TestHelper

  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.Schemas.Serial.Account
  alias VBT.TestRepo

  setup do
    Sandbox.checkout(TestRepo)
  end

  describe "fetch" do
    test "returns existing row" do
      account = insert_account!()
      assert TestRepo.fetch(Account, account.id) == {:ok, account}
    end

    test "returns error if row not found" do
      assert TestRepo.fetch(Account, -1) == {:error, "Account not found"}
    end

    test "uses a custom tag in error message" do
      assert TestRepo.fetch(Account, -1, tag: "User") == {:error, "User not found"}
    end

    test "uses a custom error in error message" do
      assert TestRepo.fetch(Account, -1, error: "Not found") == {:error, "Not found"}
    end
  end

  describe "fetch_by" do
    test "returns existing row" do
      account = insert_account!()

      assert TestRepo.fetch_by(Account, name: account.name) == {:ok, account}
      assert TestRepo.fetch_by(Account, id: account.id, name: account.name) == {:ok, account}
    end

    test "supports query as input" do
      account1 = insert_account!()
      _account2 = insert_account!()
      query = from account in Account, select: account.name
      assert TestRepo.fetch_by(query, id: account1.id) == {:ok, account1.name}
    end

    test "returns error if row not found" do
      assert TestRepo.fetch_by(Account, name: "invalid name") == {:error, "Account not found"}
    end

    test "returns a generic error if input is a query" do
      query = from account in Account, select: account.name
      assert TestRepo.fetch_by(query, id: -1) == {:error, "Record not found"}
    end

    test "uses a custom tag in error message" do
      assert TestRepo.fetch_by(Account, [id: -1], tag: "User") == {:error, "User not found"}
    end

    test "uses a custom error in error message" do
      assert TestRepo.fetch_by(Account, [id: -1], error: "Not found") == {:error, "Not found"}
    end
  end

  describe "fetch_one" do
    test "returns existing row" do
      account = insert_account!()
      assert TestRepo.fetch_one(from Account, where: [id: ^account.id]) == {:ok, account}
    end

    test "doesn't treat null as a missing value" do
      account = insert_account!()

      assert TestRepo.fetch_one(from Account, where: [id: ^account.id], select: fragment("NULL")) ==
               {:ok, nil}
    end

    test "returns error if row not found" do
      assert TestRepo.fetch_one(from Account, where: [id: -1]) == {:error, "Record not found"}
    end

    test "uses a custom tag in error message" do
      assert TestRepo.fetch_one(from(Account, where: [id: -1]), tag: "User") ==
               {:error, "User not found"}
    end

    test "uses a custom error in error message" do
      assert TestRepo.fetch_one(from(Account, where: [id: -1]), error: "Not found") ==
               {:error, "Not found"}
    end
  end

  defp insert_account!(data \\ []) do
    data =
      ~w/name email password_hash/a
      |> Enum.map(&{&1, "#{&1}_#{unique_positive_integer()}"})
      |> Keyword.merge(data)

    TestRepo.insert!(struct!(Account, data))
  end
end
