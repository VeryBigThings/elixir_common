defmodule VBT.Schemas.Serial.Token do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "tokens_serial_id" do
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime
    belongs_to :account, VBT.Schemas.Serial.Account
    timestamps()
  end
end
