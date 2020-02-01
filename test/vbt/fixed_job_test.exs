defmodule VBT.FixedJobTest do
  use ExUnit.Case, async: true
  import Periodic.Test
  alias VBT.FixedJob

  for property <- ~w/minute hour day_of_week day month year/a do
    @property property
    @expected_value if @property == :day_of_week, do: :monday, else: 1
    @unexpected_value if @property == :day_of_week, do: :tuesday, else: 2

    test "job is started if current time matches the `#{@property}` key" do
      scheduler = start_scheduler!(%{@property => @expected_value})
      FixedJob.set_time(scheduler, %{@property => @expected_value})
      assert sync_tick(scheduler) == {:ok, :normal}
    end

    test "job isn't started if current time doesn't match the `#{@property}` key" do
      scheduler = start_scheduler!(%{@property => @expected_value})
      FixedJob.set_time(scheduler, %{@property => @unexpected_value})
      assert sync_tick(scheduler) == {:error, :job_not_started}
    end
  end

  test "job is started if current time matches keys in filter" do
    scheduler = start_scheduler!(%{day: 1, minute: 1})

    FixedJob.set_time(scheduler, %{year: 1, day: 1, minute: 1})
    assert sync_tick(scheduler) == {:ok, :normal}

    FixedJob.set_time(scheduler, %{day: 1, hour: 2, minute: 1})
    assert sync_tick(scheduler) == {:ok, :normal}
  end

  test "job isn't started if current time doesn't match keys in filter" do
    scheduler = start_scheduler!(%{day: 1, minute: 1})

    FixedJob.set_time(scheduler, %{day: 2, minute: 1})
    assert sync_tick(scheduler) == {:error, :job_not_started}

    FixedJob.set_time(scheduler, %{day: 1, minute: 2})
    assert sync_tick(scheduler) == {:error, :job_not_started}
  end

  defp start_scheduler!(filter, opts \\ []) do
    test_process = self()

    opts =
      Keyword.merge(
        [mode: :manual, when: filter, run: fn -> send(test_process, :job_started) end],
        opts
      )

    start_supervised!({FixedJob, opts})
  end
end
