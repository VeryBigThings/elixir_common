defmodule VBT.Provider.SystemEnv do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  @moduledoc "Provider storage adapter which retrieves values from OS env vars."
  @behaviour VBT.Provider.Adapter

  @impl VBT.Provider.Adapter
  def display_name(param_name), do: param_name |> Atom.to_string() |> String.upcase()

  @impl VBT.Provider.Adapter
  def values(param_names), do: Enum.map(param_names, &System.get_env(display_name(&1)))
end
