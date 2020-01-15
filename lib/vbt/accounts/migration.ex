defmodule VBT.Accounts.Migration do
  import Ecto.Migration

  @type config :: %{tokens_table: String.t(), accounts_table: String.t(), type: type}
  @type type :: :serial | :bigserial | :uuid

  @spec change(config) :: any
  def change(config) do
    create table(config.tokens_table, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :account_id, references(config.accounts_table, type: config.type), null: false
    end

    create index(config.tokens_table, [:account_id])
  end
end
