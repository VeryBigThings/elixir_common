defmodule VBT.TestRepo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts_serial_id, primary_key: false) do
      add :id, :serial, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :text, null: false
    end

    create unique_index(:accounts_serial_id, [:email])

    VBT.Accounts.Migration.change(%{
      tokens_table: "tokens_serial_id",
      accounts_table: "accounts_serial_id",
      type: :serial
    })

    create table(:accounts_uuid, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :text, null: false
    end

    create unique_index(:accounts_uuid, [:email])

    VBT.Accounts.Migration.change(%{
      tokens_table: "tokens_uuid",
      accounts_table: "accounts_uuid",
      type: :uuid
    })
  end
end
