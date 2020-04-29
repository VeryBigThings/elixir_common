defmodule VBT.Kubernetes.Probe do
  @moduledoc """
  Plug for handling kubernetes liveness probe checks.

  To use it, add `plug VBT.Kubernetes.Probe, "/authz"` in your endpoint.
  """

  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(path), do: String.split(path, "/", trim: true)

  @impl Plug
  def call(conn, path_info) do
    if conn.method == "GET" and conn.path_info == path_info,
      do: conn |> resp(:ok, "") |> halt(),
      else: conn
  end
end
