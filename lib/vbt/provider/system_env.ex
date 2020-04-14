defmodule VBT.Provider.SystemEnv do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  @moduledoc false

  @behaviour VBT.Provider.Source
  alias VBT.Provider.Source

  @impl Source
  def display_name(param_name), do: param_name |> Atom.to_string() |> String.upcase()

  @impl Source
  def values(param_names), do: Enum.map(param_names, &System.get_env(display_name(&1)))

  @impl Source
  def template(params) do
    params
    |> Enum.sort()
    |> Enum.map(&param_entry/1)
    |> Enum.join("\n")
  end

  defp param_entry({name, %{default: nil} = spec}) do
    """
    # #{spec.type}
    #{display_name(name)}=
    """
  end

  defp param_entry({name, spec}) do
    """
    # #{spec.type}
    # #{display_name(name)}=#{spec.default}
    """
  end
end
