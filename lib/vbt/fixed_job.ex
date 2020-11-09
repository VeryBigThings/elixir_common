defmodule VBT.FixedJob do
  @moduledoc """
  Helper for running jobs with fixed schedules (e.g. once a day at midnight).

  ## Basic usage

  In most cases it's advised to define a dedicated module. For example, the following module
  defines a cleanup job which runs once a day at midnight UTC:

      defmodule DailyCleanup do
        def child_spec(_) do
          VBT.FixedJob.child_spec(
            id: __MODULE__,
            name: __MODULE__,
            run: &cleanup/0,

            # configures desired time
            when: %{hour: 0, minute: 0},

            # prevents periodic job from running automatically in test mode
            mode: unquote(if Mix.env() == :test, do: :manual, else: :automatic)
          )
        end

        defp cleanup() do
          # ...
        end
      end

  Now, you can include `DailyCleanup` as a child of some supervisor.

  ### Testing

  The job can be tested as follows:

      test "cleanup scheduler" do
        # The job is registered under a name so we can find its pid
        scheduler_pid = Process.whereis(DailyCleanup)

        # Needed only if the scheduler works with the database
        Sandbox.allow(Repo, self(), scheduler_pid)

        # mock the current time in the scheduler
        VBT.FixedJob.set_time(scheduler_pid, %{hour: 0, minute: 0})

        # ticks the scheduler, waits for the job to finish, and asserts that it exited normally
        assert Periodic.Test.sync_tick(scheduler_pid) == {:ok, :normal}

        # verify side-effects of the job here
      end

  You can test multiple different jobs from separate async ExUnit cases. However, the same
  job should either be tested from a single case (preferred), or all cases testing the scheduler
  should be synchronous (`async: false`).

  ## Options

  - `:when` - parts of the `DateTime.t` struct which you want to match. In addition, the
    `:day_of_week` key is supported with values of the `t:day_of_week/0` type.
  - `:now_fun` - Optional zero arity function (or MFA) which is invoked by the scheduler to get
    the current date/time. By default, `DateTime.utc_now/0` is used.
  - The remaining options in the `t:opts/0` type are specific to `Periodic`. See the corresponding
    docs for details.
  """

  @type opts :: [
          id: any,
          name: GenServer.name(),
          telemetry_id: term(),
          run: (() -> any) | {module, atom, [any]},
          when: filter,
          now_fun: (() -> any) | {module, atom, [any]},
          on_overlap: :run | :ignore | :stop_previous,
          timeout: pos_integer() | :infinity,
          job_shutdown: :brutal_kill | :infinity | non_neg_integer(),
          mode: :auto | :manual
        ]

  @type filter :: %{
          optional(:minute) => Calendar.minute(),
          optional(:hour) => Calendar.hour(),
          optional(:day_of_week) => day_of_week,
          optional(:day) => Calendar.day(),
          optional(:month) => Calendar.month(),
          optional(:year) => Calendar.year()
        }

  @type day_of_week :: :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Returns the supervisor child specification for the scheduler process."
  @spec child_spec(opts) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :id, __MODULE__),
      type: :supervisor,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc "Starts the scheduler process."
  @spec start_link(opts) :: GenServer.on_start()
  def start_link(opts) do
    {condition_fun, opts} = condition_fun(opts)
    Periodic.start_link(Keyword.merge(opts, when: condition_fun, every: :timer.seconds(1)))
  end

  @doc """
  Sets the time of the scheduler process.

  This function should only be used in tests, and will only work if the scheduler mode is set to
  `:manual`. Typically you want to invoke this function before calling Periodic.Test.tick/2. You
  don't need to provide the complete date/time. Only the parts which are of interest can be passed.
  The scheduler will fill in the rest via the now function (see the `:now_fun` option).
  """
  @spec set_time(GenServer.server(), filter) :: :ok
  def set_time(scheduler, time_overrides) do
    pid = GenServer.whereis(scheduler)
    true = is_pid(pid)
    :ets.insert(__MODULE__.TimeProvider, {pid, time_overrides})
    :ok
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp condition_fun(opts) do
    {filter, opts} = Keyword.pop_lazy(opts, :when, fn -> raise "when filter missing" end)
    filter = Map.put(filter, :second, 0)

    {now_fun, opts} = Keyword.pop(opts, :now_fun, &DateTime.utc_now/0)

    now_fun =
      if Keyword.get(opts, :mode, :auto) == :auto,
        do: now_fun,
        else: instrumented_now(now_fun)

    {fn -> matches_filter?(now_fun.(), filter) end, opts}
  end

  defp instrumented_now(now_fun) do
    fn ->
      case :ets.lookup(__MODULE__.TimeProvider, self()) do
        [{_key, time_overrides}] ->
          {day_of_week, time_overrides} = Map.pop(time_overrides, :day_of_week)

          now_fun.()
          |> Map.merge(time_overrides)
          |> Map.put(:second, 0)
          |> on_day_of_week(day_of_week)

        _ ->
          raise "in manual mode scheduler time must be manually set via `set_time`"
      end
    end
  end

  defp on_day_of_week(date_time, nil), do: date_time

  defp on_day_of_week(date_time, day_name) do
    date_time
    |> Stream.iterate(&DateTime.add(&1, 60 * 60 * 24, :second))
    |> Enum.find(&(day_name(Date.day_of_week(&1)) == day_name))
  end

  defp matches_filter?(now, filter),
    do: Enum.all?(filter, fn {key, expected} -> expected == value(now, key) end)

  defp value(now, :day_of_week), do: now |> Date.day_of_week() |> day_name()
  defp value(now, key), do: Map.fetch!(now, key)

  ~w/monday tuesday wednesday thursday friday saturday sunday/a
  |> Enum.with_index(1)
  |> Enum.each(fn {name, index} -> defp day_name(unquote(index)), do: unquote(name) end)

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def init_time_provider do
    :ets.new(
      __MODULE__.TimeProvider,
      [:named_table, :public, read_concurrency: true, write_concurrency: true]
    )
  end
end
