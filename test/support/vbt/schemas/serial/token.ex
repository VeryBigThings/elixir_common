defmodule VBT.Schemas.Serial.Token do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "tokens_serial_id" do
    field :hash, :binary
    field :type, :string
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime
    belongs_to :account, VBT.Schemas.Serial.Account
  end
end
