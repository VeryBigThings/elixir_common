## 2020-02-06

###  **[Breaking]** Oban 1.0

Oban 1.0 is now used as a dependency, which requires adding a database migration:

```elixir
defmodule MySystem.Repo.Migrations.MigrateOban10 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end
``

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
