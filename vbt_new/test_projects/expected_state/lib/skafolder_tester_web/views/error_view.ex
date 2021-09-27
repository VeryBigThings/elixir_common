# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterWeb.ErrorView do
  use SkafolderTesterWeb, :view

  def render("500.json", %{kind: kind, reason: reason, stack: stack}) do
    # sending formatted exception to frontend on develop, preview, and stage
    message =
      if System.get_env("RELEASE_LEVEL") in ~w/develop preview stage/,
        do: Exception.format(kind, reason, stack),
        else: "Internal Server Error"

    %{errors: [%{message: message}]}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    message = Phoenix.Controller.status_message_from_template(template)

    if Path.extname(template) == ".json",
      do: %{errors: [%{message: message}]},
      else: message
  end
end
