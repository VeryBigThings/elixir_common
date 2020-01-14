defmodule VBT.TestRepo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :text, null: false
    end

    create unique_index(:accounts, [:email])

    VBT.Accounts.Migration.change(%{tokens_table: "tokens", accounts_table: "accounts"})
  end
end
