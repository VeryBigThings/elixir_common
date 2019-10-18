defmodule Mix.Vbt do
  def bindings(opts \\ [], defaults \\ []) do
    app = otp_app()
    additional_bindings = Keyword.merge(defaults, opts)

    [app: app, base_module: base_module(app)]
    |> Keyword.merge(additional_bindings)
  end

  defp base_module(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Macro.camelize()
      mod -> mod |> inspect()
    end
  end

  defp otp_app do
    Mix.Project.config() |> Keyword.fetch!(:app)
  end
end
