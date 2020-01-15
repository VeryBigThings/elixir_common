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

    create table(:tokens_serial_id, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :account_id, references(:accounts_serial_id, type: :serial), null: false
    end

    create table(:accounts_uuid, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :text, null: false
    end

    create unique_index(:accounts_uuid, [:email])

    create table(:tokens_uuid, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :account_id, references(:accounts_uuid, type: :uuid), null: false
    end
  end
end
