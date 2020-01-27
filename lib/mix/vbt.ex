defmodule Mix.Vbt do
  @moduledoc false

  @spec otp_app :: atom
  def otp_app, do: Keyword.fetch!(Mix.Project.config(), :app)

  @spec endpoint_module :: module
  def endpoint_module, do: Module.concat(Macro.camelize("#{otp_app()}_web"), Endpoint)

  @spec repo_module :: module
  def repo_module, do: Module.concat(Macro.camelize("#{otp_app()}"), Repo)

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  def bindings(opts \\ [], defaults \\ []) do
    app = otp_app()
    additional_bindings = Keyword.merge(defaults, opts)
    Keyword.merge([app: app, base_module: base_module(app)], additional_bindings)
  end

  defp base_module(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Macro.camelize()
      mod -> inspect(mod)
    end
  end
end
