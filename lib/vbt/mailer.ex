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

      config :my_project, Oban, crontab: false, queues: false, plugins: false

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
        use VBT.Mailer,
          oban_worker: [queue: "email"],
          templates: "templates",
          adapter: Bamboo.SendGridAdapter

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

        @impl VBT.Mailer
        def config(), do: %{api_key: System.fetch_env!("SENDGRID_API_KEY")}
      end

  Mailer is a wrapper around Bamboo, so it can use any conforming adapter. The adapter will only
  be used in `:prod`. Mailer always uses `Bamboo.LocalAdapter` in `:dev`, and `Bamboo.TestAdapter`
  in `:test`.

  If you prefer to test the real adapter in development mode, you can pass the
  `dev_adapter: Bamboo.SendGridAdapter` option (or any other real adapter you're using). However,
  it's advised to instead test the real mailer by running the `:prod`-compiled version locally.

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

  ## Dynamic repos

  If you need to run multiple instances of mailer, pass the `:name` option to Oban instance. Then
  you need to pass the same name as an option to `enqueue/6` and `drain_queue/0`.
  """

  alias Bamboo.{Attachment, Email}

  @type body ::
          String.t()
          | %{text: String.t(), html: String.t()}
          | %{
              required(:layout) => atom,
              required(:template) => atom | String.t(),
              optional(atom) => any
            }

  @type opts :: [
          attachments: [Attachment.t()],
          cc: [address_list()],
          bcc: [address_list()],
          headers: %{String.t() => String.t()},
          name: GenServer.server()
        ]

  # using our own versions of bamboo types due to an error in bamboo spec
  @type address :: String.t() | {String.t(), String.t()}
  @type address_list :: nil | address | [address] | any

  @callback config :: map

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Composes the email and sends it to the target address."
  @spec send!(module, address_list(), address_list(), String.t(), body, opts) :: :ok
  def send!(mailer, from, to, subject, body, opts \\ []) do
    opts = Keyword.update(opts, :attachments, [], &normalize_attachments/1)
    [adapter] = Keyword.fetch!(mailer.__info__(:attributes), __MODULE__)
    config = mailer.config()

    email =
      [from: from, to: to, subject: subject]
      |> Keyword.merge(Keyword.take(opts, ~w/attachments cc bcc headers/a))
      |> Email.new_email()
      |> set_body(body, mailer)

    Bamboo.Mailer.deliver_now!(adapter, email, config, [])

    :ok
  end

  @doc "Enqueues the mail for sending."
  @spec enqueue(module, address(), address(), String.t(), body, opts :: opts) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(mailer, from, to, subject, body, opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, Oban)

    # Technically it would be enough to do this normalization in `send!`. However, we're also
    # doing it here to raise early if there are some error in input opts.
    opts = Keyword.update(opts, :attachments, [], &normalize_attachments/1)

    changeset =
      %{from: from, to: to, subject: subject, body: body, opts: opts}
      |> encode_for_queue()
      |> mailer.new()

    Oban.insert(name, changeset)
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp normalize_attachments(attachments),
    do: Enum.map(attachments, &normalize_attachment/1)

  defp normalize_attachment(%Attachment{data: nil} = attachment) do
    if is_nil(attachment.path), do: raise("missing file path or attachment data")

    %Attachment{
      data: File.read!(attachment.path),
      filename: attachment.filename || Path.basename(attachment.path)
    }
  end

  defp normalize_attachment(attachment) do
    if is_nil(attachment.filename), do: raise("missing filename")
    attachment
  end

  defp set_body(email, body, _mailer) when is_binary(body),
    do: Email.text_body(email, body)

  defp set_body(email, %{text: text_body, html: html_body}, _mailer) do
    email
    |> Email.text_body(text_body)
    |> Email.html_body(html_body)
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
    %{"encoded" => args |> :erlang.term_to_binary() |> Base.encode64(padding: false)}
  end

  # ------------------------------------------------------------------------
  # __using__
  # ------------------------------------------------------------------------

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour unquote(__MODULE__)

      unquote(bamboo_fragment(opts))
      unquote(phoenix_fragment(opts))
      unquote(oban_fragment(opts))
    end
  end

  defp bamboo_fragment(opts) do
    quote bind_quoted: [module: __MODULE__, opts: opts] do
      adapter =
        case Mix.env() do
          :dev -> Keyword.get(opts, :dev_adapter, Bamboo.LocalAdapter)
          :test -> Bamboo.TestAdapter
          :prod -> Keyword.fetch!(opts, :adapter)
        end

      Module.register_attribute(__MODULE__, module, persist: true)
      Module.put_attribute(__MODULE__, module, adapter)
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
        def perform(job) do
          args =
            job.args
            |> Map.fetch!("encoded")
            |> Base.decode64!(padding: false)
            |> :erlang.binary_to_term()

          VBT.Mailer.send!(__MODULE__, args.from, args.to, args.subject, args.body, args.opts)
        end

        @impl Oban.Worker
        # credo:disable-for-next-line Credo.Check.Readability.Specs
        def backoff(job) do
          # These delays, together with the default number of attempts (30) will cause
          # the queue to retry sending the mail for at most 24 hours.
          delays = {1, 2, 3, 4, 10, 20, 20, 60}
          elem(delays, min(job.attempt - 1, tuple_size(delays) - 1)) * 60
        end

        # Add a helper `drain_queue` function to simplify testing.
        if Mix.env() == :test do
          # Using any in the spec, since the result type varies depending on the Oban version.
          @spec drain_queue(name: GenServer.server()) :: any
          def drain_queue(opts \\ []) do
            Oban.drain_queue(
              Keyword.get(opts, :name, Oban),
              unquote(queue: Keyword.fetch!(oban_opts, :queue))
            )
          end
        end

        defoverridable Oban.Worker
      end
    end
  end
end
