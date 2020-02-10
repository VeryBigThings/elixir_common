defmodule VBT.Provider.SystemEnv do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  @moduledoc "Provider source which retrieves values from OS env vars."
  @behaviour VBT.Provider.Source

  @impl VBT.Provider.Source
  def display_name(param_name), do: param_name |> Atom.to_string() |> String.upcase()

  @impl VBT.Provider.Source
  def values(param_names), do: Enum.map(param_names, &System.get_env(display_name(&1)))
end
