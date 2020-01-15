defmodule VBT.Schemas.Uuid.Account do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "accounts_uuid" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
    has_many :tokens, VBT.Schemas.Uuid.Token
  end
end
