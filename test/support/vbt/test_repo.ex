defmodule VBT.TestRepo do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use VBT.Repo, otp_app: :vbt, adapter: Ecto.Adapters.Postgres

  @doc false
  def init(_type, opts),
    do: {:ok, opts |> Keyword.merge(access_opts()) |> Keyword.merge(common_opts())}

  defp common_opts do
    [
      database: "vbt_test",
      pool: Ecto.Adapters.SQL.Sandbox,
      show_sensitive_data_on_connection_error: true
    ]
  end

  defp access_opts do
    if System.get_env("CI"),
      do: [username: "postgres", password: "postgres"],
      else: [socket_dir: "/var/run/postgresql"]
  end
end
