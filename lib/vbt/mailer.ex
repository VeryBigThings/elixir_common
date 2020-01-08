defmodule VBT.Mailer do
  @moduledoc """
  Helper for simpler e-mail sending using Bamboo and Phoenix templates.

  This module simplifies the implementation of a typical e-mail sending logic, by conflating
  mailer, composer, and templating concerns into a single module.

  ## Example

      defmodule MyMailer do
        use VBT.Mailer, templates: "templates"

          @spec send_password_reset(String.t(), String.t()) :: :ok
          def send_password_reset(email, password_reset_link) do
            VBT.Mailer.send!(
              __MODULE__,
              "sender@x.y.z",
              "recipient@x.y.z",
              "Reset your password",
              %{
                layout: :some_layout,
                template: :some_template,
                password_reset_link: password_reset_link
              }
            )
          end
        def
      end

  Note that `MyMailer` is a Bamboo mailer, so it should be configured in config scripts.

  The template files (.eex) should be placed into the `templates` folder, relative to the mailer
  file.

  The code above expects both .text and .html files to exist. If you want to use the text format
  only, you need to provide template as a string, and have it end with the .text suffix:

      %{layout: :some_layout, template: "some_template.text"}

  Note that layout is always provided as atom, without the extension. Bamboo will correctly
  use `some_layout.text.eex` to render the layout.

  All other data in the map is forwarded as assigns to the template. In the example above,
  a template can reference `@password_reset_link`

  ## Using without templates

  It is also possible to use mailer without Phoenix templates. In this case, you don't need to
  provide the `:templates` option in `use`. When sending an e-mail, you can provide plain string
  for the body argument. This string is used as the text body. If you wish to provide both text
  and the html body, you can use `%{text: text_body, html: html_body}`.
  """

  @type body ::
          String.t()
          | %{text: String.t(), html: String.t()}
          | %{
              required(:layout) => atom,
              required(:template) => atom | String.t(),
              optional(atom) => any
            }

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc false
  defmacro __using__(opts) do
    phoenix_fragment =
      with {:ok, templates_path} <- Keyword.fetch(opts, :templates) do
        quote do
          root =
            __ENV__.file
            |> Path.dirname()
            |> Path.relative_to_cwd()
            |> Path.join(unquote(templates_path))

          use Phoenix.View, root: root, namespace: __MODULE__
        end
      end

    quote do
      app = Keyword.fetch!(Mix.Project.config(), :app)
      use Bamboo.Mailer, otp_app: app
      unquote(phoenix_fragment)
    end
  end

  @doc "Composes the email and sends it to the target address."
  @spec send!(module, Bamboo.Email.address(), Bamboo.Email.address(), String.t(), body) :: :ok
  def send!(mailer, from, to, subject, body) do
    Bamboo.Email.new_email(from: from, to: to, subject: subject)
    |> set_body(body, mailer)
    |> mailer.deliver_now()

    :ok
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp set_body(email, body, _mailer) when is_binary(body),
    do: Bamboo.Email.text_body(email, body)

  defp set_body(email, %{text: text_body, html: html_body}, _mailer) do
    email
    |> Bamboo.Email.text_body(text_body)
    |> Bamboo.Email.html_body(html_body)
  end

  defp set_body(email, %{layout: layout, template: template} = body, mailer) do
    email = Bamboo.Phoenix.put_layout(email, {mailer, layout})
    assigns = Map.drop(body, [:layout, :template])
    Bamboo.Phoenix.render_email(mailer, email, template, assigns)
  end
end
