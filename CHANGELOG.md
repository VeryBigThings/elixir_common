## 2020-08-11

**[Breaking]** Uses oban 2.0. If you use oban, you'll need to go through all of the instructions from the [upgrade guide](https://hexdocs.pm/oban/v2-0.html#content). If you don't use oban, but use `VBT.Mailer`, you only need to adapt the config files (see [this section](https://hexdocs.pm/oban/v2-0.html#update-your-config)).  If neither oban nor `VBT.Mailer` is used, nothing needs to be changed.

## 2020-06-04

**[Breaking]** `VBT.Graphql.Scalars` is renamed to `VBT.Graphql.Types`. This will only break the compilation if you have been using the module directly. However, if you use it through `VBT.Absinthe.Schema`, you don't need to make any changes.

## 2020-04-24

**[Breaking]** `VBT.aws_client/0` is deprecated. Use `VBT.Aws.client/0` instead.

## 2020-04-22

**[Breaking]** The credo check `VBT.Credo.Check.Readability.WithPlaceholder` has been removed. Use `Credo.Check.Readability.WithCustomTaggedTuple` instead. Adapt `.credo.exs` accordingly.


## 2020-04-09

###  **[Breaking]** Accounts and Tokens logic

User tokens can now be used if the user login is not available. This allows implementing simpler
APIs, where e.g. frontend doesn't have to send the e-mail for a password reset. To make this
work, the token mechanism has been significantly changed. Consequently, some changes must be made
in the client projects using the tokens logic:

First, migrate the token database. Example:

```elixir
def up do
  execute "truncate table tokens"

  alter table(:tokens) do
    add :hash, :binary, null: false
    add :type, :string, null: false
    modify :user_id, :uuid, null: true
  end

  create unique_index(:tokens, [:hash])
end

def down do
  execute "truncate table tokens"

  alter table(:tokens) do
    remove :hash
    remove :type
    modify :user_id, :uuid, null: false
  end
end
```

Add the new fields `hash` and `type` to the Ecto schema:

```elixir
defmodule MySystem.Schemas.Token do
  # ...

  schema "tokens" do
    field :hash, :binary
    field :type, :string
    # ...
  end
end
```

Next, you need to adapt the code to the new API. The interface of `VBT.Accounts.reset_password`
and `VBT.Accounts.Token.use` has been changed (see docs for details). In addition, the function
`VBT.Accounts.Token.decode` has been removed. Instead of that function you can immediately invoke
`use`, which will perform the token validation.

Finally, remove the `:secret_key_base` field from the accounts config.


## 2020-02-06

###  **[Breaking]** Oban 1.0

Oban 1.0 is now used as a dependency, which requires adding a database migration:

```elixir
defmodule MySystem.Repo.Migrations.MigrateOban10 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end
```

### **[Breaking]** VBT.Mailer adapter configuration

`VBT.Mailer` is not configured through app env anymore. Instead of this:

```elixir
config :my_app, MyMailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: {:system, "SENDGRID_API_KEY"}
```

You should do this:

```elixir
defmodule MyMailer do
  use VBT.Mailer, adapter: Bamboo.SendgridAdapter

  @impl VBT.Mailer
  def config, do: %{api_key: System.fetch_env!("SENDGRID_API_KEY")}
end
```

All related entries from config.exs & friends (dev/test/prod/release) should be removed. `VBT.Mailer` will use `Bamboo.TestAdapter` in test env, and `Bamboo.LocalAdapter` in dev.
