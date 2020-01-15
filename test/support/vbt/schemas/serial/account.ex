defmodule VBT.Schemas.Serial.Account do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}

  schema "accounts_serial_id" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
    has_many :tokens, VBT.Schemas.Serial.Token
  end
end
