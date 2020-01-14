defmodule VBT.Schemas.AccountSerialId do
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}

  schema "accounts_serial_id" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
  end
end

defmodule VBT.Schemas.AccountUuid do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "accounts_uuid" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
  end
end
