defmodule VBT.Schemas.Uuid.Token do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "tokens_uuid" do
    field :hash, :binary
    field :type, :string
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime
    belongs_to :account, VBT.Schemas.Uuid.Account, type: :binary_id
  end
end
