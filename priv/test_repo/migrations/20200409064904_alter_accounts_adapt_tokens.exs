defmodule VBT.TestRepo.Migrations.AlterAccountsAdaptTokens do
  use Ecto.Migration

  def up do
    execute "truncate table tokens_serial_id"

    alter table(:tokens_serial_id) do
      add :hash, :binary, null: false
      add :type, :string, null: false
      modify :account_id, :integer, null: true
    end

    create unique_index(:tokens_serial_id, [:hash])

    execute "truncate table tokens_uuid"

    alter table(:tokens_uuid) do
      add :hash, :binary, null: false
      add :type, :string, null: false
      modify :account_id, :uuid, null: true
    end

    create unique_index(:tokens_uuid, [:hash])
  end

  def down do
    execute "truncate table tokens_serial_id"

    alter table(:tokens_serial_id) do
      remove :type
      remove :hash
      modify :account_id, :integer, null: false
    end

    execute "truncate table tokens_uuid"

    alter table(:tokens_uuid) do
      remove :type
      remove :hash
      modify :account_id, :uuid, null: false
    end
  end
end
