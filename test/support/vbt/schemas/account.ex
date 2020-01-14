defmodule VBT.Schemas.Account do
  use Ecto.Schema

  schema "accounts" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
  end
end
