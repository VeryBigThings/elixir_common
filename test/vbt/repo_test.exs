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

  describe "transact" do
    test "succeeds if the function returns {:ok, result}" do
      assert {:ok, returned_account} = TestRepo.transact(fn -> {:ok, insert_account!()} end)
      assert TestRepo.one!(Account) == returned_account
    end

    test "accepts arity 1 function as argument" do
      TestRepo.transact(fn repo ->
        assert repo == TestRepo
        {:ok, nil}
      end)
    end

    test "rolls back if the function returns {:error, reason}" do
      fun = fn ->
        insert_account!()
        {:error, :some_reason}
      end

      assert TestRepo.transact(fun) == {:error, :some_reason}
      assert TestRepo.one(Account) == nil
    end
  end

  describe "delete_one" do
    test "deletes the desired row" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.delete_one(from Account, where: [id: ^account1.id]) == :ok
      assert TestRepo.all(from account in Account, select: account.id) == [account2.id]
    end

    test "returns the selected expression" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.delete_one(
               from account in Account,
                 where: [id: ^account1.id],
                 select: account
             ) == {:ok, account1}

      assert TestRepo.all(from account in Account, select: account.id) == [account2.id]
    end

    test "fails if no record is matched" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.delete_one(from Account, where: [id: -1]) == {:error, :not_found}

      assert TestRepo.all(from account in Account, select: account.id) == [
               account1.id,
               account2.id
             ]
    end

    test "fails if multiple records are matched" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.delete_one(
               from account in Account,
                 where: account.id in [^account1.id, ^account2.id]
             ) == {:error, :multiple_rows}

      assert TestRepo.all(from account in Account, select: account.id) == [
               account1.id,
               account2.id
             ]
    end

    test "succeeds inside the transaction desired row" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.transact(fn ->
               TestRepo.delete_one(
                 from account in Account,
                   where: [id: ^account1.id],
                   select: account
               )
             end) == {:ok, account1}

      assert TestRepo.all(from account in Account, select: account.id) == [account2.id]
    end

    test "returns error inside a transaction" do
      account1 = insert_account!()
      account2 = insert_account!()

      assert TestRepo.transact(fn ->
               account3 = insert_account!()
               with :ok <- TestRepo.delete_one(from Account, where: [id: -1]), do: {:ok, account3}
             end) == {:error, :not_found}

      assert TestRepo.all(from account in Account, select: account.id) == [
               account1.id,
               account2.id
             ]
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
