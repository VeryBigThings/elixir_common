defmodule VBT.Mailer do
  @moduledoc """
  Helper for simpler e-mail sending using Bamboo and Phoenix templates.

  This module simplifies the implementation of a typical e-mail sending logic, by conflating
  mailer, composer, database-backed queue, and templating concerns into a single module.

  ## Example

  In a typical scenario, it is advised to use `VBT.Mailer` together with Oban based persistent
  queue. The queue improves delivery guarantees, reducing the chance of e-mail not being sent
  if something goes wrong (for example, if the mail server is not reachable).

  To do this, you need to first create a new migration which initializes Oban tables:

      defmodule MyProject.Migrations.InitializeOban do
        use Ecto.Migration

        def up, do: Oban.Migrations.up()
        def down, do: Oban.Migrations.down()
      end

  Then you need to configure the email queue in `config.exs`

      # `email: 10` defines the queue called "emails" with the maximum concurrency of 10
      config :my_project, Oban, repo: MyRepo, queues: [email: 10]

  Make sure to disable queues in `config/test.exs`:

      config :my_project, Oban, crontab: false, queues: false, prune: :disabled

  Next, you need to start the oban process tree in your application:

      defmodule MyProject.Application do
        # ...

        def start(_type, _args) do
          children = [
            # ...
            MyRepo,
            # make sure to start oban after the repo
            {Oban, Application.fetch_env!(:my_project, Oban)},
            # ...
          ]

          # ...
        end
      end

  Finally, you can define the mailer module in your context:

      defmodule MyMailer do
        # Note that `MyMailer` is also a Bamboo mailer, so it should be configured in config
        # scripts.
        use VBT.Mailer,
          oban_worker: [queue: "email"],
          templates: "templates"

          @spec send_password_reset(String.t(), String.t()) ::
            {:ok, Oban.Job.t} | {:error, Ecto.Changeset.t}
          def send_password_reset(email, password_reset_link) do
            VBT.Mailer.enqueue(
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

  ## Transactions

  If you need to send an e-mail inside a transaction, you can invoke `enqueue/5` from within
  `Ecto.Multi.run/3`:

      Ecto.Multi.run(multi, :enqueue_mail, fn _repo, _arg -> VBT.Mailer.enqueue(...) end)

  In this case, the e-mail will be enqueued once the transaction is committed. If the transaction
  is rolled back, the e-mail will not be enqueued.

  ## Queue options

  The `:oban_worker` options are passed to [Oban.Worker](https://hexdocs.pm/oban/Oban.Worker.html#content).
  By default, the `:max_attempts` value and the auto generated backoff strategy will cause the
  queue to retry for at most 24 hours.

  ## Body templates

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

  ## Immediate sending

  If you want to skip the queue, you can use `send!/5`, which will send the mail synchronously.
  In this case, you don't need to provide the `:oban_worker` option when using this module.

  ## Testing

  If e-mails are sent through the queue, you need to manually drain the queue before checking
  for the delivery. For this purpose, a helper `drain_queue` function is injected into your
  mailer module, but only in the `:test` environment:

        test "sends reset password email" do
          MyMailer.send_password_reset(email, reset_links)

          MyMailer.drain_queue()

          mail = assert_delivered_email(to: [{_, ^email}])
          assert mail.text_body =~ reset_link
        end
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

  @doc "Composes the email and sends it to the target address."
  @spec send!(module, Bamboo.Email.address(), Bamboo.Email.address(), String.t(), body) :: :ok
  def send!(mailer, from, to, subject, body) do
    Bamboo.Email.new_email(from: from, to: to, subject: subject)
    |> set_body(body, mailer)
    |> mailer.deliver_now()

    :ok
  end

  @doc "Enqueues the mail for sending."
  @spec enqueue(module, Bamboo.Email.address(), Bamboo.Email.address(), String.t(), body) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(mailer, from, to, subject, body) do
    %{from: from, to: to, subject: subject, body: body}
    |> encode_for_queue()
    |> mailer.new()
    |> Oban.insert()
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

  defp encode_for_queue(args) do
    # Before data is sent to Oban queue, it is encoded using `term_to_binary` and `Base.encode64`.
    # This allows us to easily store tuples (needed for senders and recepients), and atoms into
    # the database, and get this data preserved after deserialization.
    %{"args" => args |> :erlang.term_to_binary() |> Base.encode64(padding: false)}
  end

  # ------------------------------------------------------------------------
  # __using__
  # ------------------------------------------------------------------------

  @doc false
  defmacro __using__(opts) do
    quote do
      app = Keyword.fetch!(Mix.Project.config(), :app)
      use Bamboo.Mailer, otp_app: app
      unquote(phoenix_fragment(opts))
      unquote(oban_fragment(opts))
    end
  end

  defp phoenix_fragment(opts) do
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
  end

  defp oban_fragment(opts) do
    with {:ok, oban_opts} <- Keyword.fetch(opts, :oban_worker) do
      quote bind_quoted: [oban_opts: oban_opts] do
        use Oban.Worker, unquote(Keyword.put_new(oban_opts, :max_attempts, 30))

        @impl Oban.Worker
        # credo:disable-for-next-line Credo.Check.Readability.Specs
        def perform(%{"args" => args}, _job) do
          args = args |> Base.decode64!(padding: false) |> :erlang.binary_to_term()
          VBT.Mailer.send!(__MODULE__, args.from, args.to, args.subject, args.body)
        end

        @impl Oban.Worker
        # credo:disable-for-next-line Credo.Check.Readability.Specs
        def backoff(attempt) do
          # These delays, together with the default number of attempts (30) will cause
          # the queue to retry sending the mail for at most 24 hours.
          delays = {1, 2, 3, 4, 10, 20, 20, 60}
          elem(delays, min(attempt - 1, tuple_size(delays) - 1)) * 60
        end

        # Add a helper `drain_queue` function to simplify testing.
        if Mix.env() == :test do
          # credo:disable-for-next-line Credo.Check.Readability.Specs
          def drain_queue,
            do: Oban.drain_queue(unquote(Keyword.fetch!(oban_opts, :queue)))
        end

        defoverridable Oban.Worker
      end
    end
  end
end
