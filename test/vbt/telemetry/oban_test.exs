defmodule VBT.Telemetry.ObanTest do
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias __MODULE__.TestQueue
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    Sandbox.checkout(VBT.TestRepo)
  end

  test "logs success" do
    on_exit(fn -> Logger.configure(level: :warn) end)
    Logger.configure(level: :debug)

    job = TestQueue.enqueue(fn -> :ok end)
    log = capture_log(fn -> TestQueue.drain_queue() end)
    assert log =~ ~s/processed job id=#{job.id} in queue "test_queue"/
  end

  test "logs exception" do
    log = run_queued_and_capture_error_log(fn -> raise("some error") end)
    assert log =~ ~s/some error/
  end

  test "logs erlang error" do
    log = run_queued_and_capture_error_log(fn -> :erlang.error("some error") end)
    assert log =~ ~s/some error/
  end

  test "logs exit" do
    log = run_queued_and_capture_error_log(fn -> exit("some error") end)
    assert log =~ ~s/some error/
  end

  test "logs throw" do
    log = run_queued_and_capture_error_log(fn -> throw("some error") end)
    assert log =~ ~s/some error/
  end

  test "logs error tuple" do
    log = run_queued_and_capture_error_log(fn -> {:error, "some error"} end)
    assert log =~ ~s/some error/
  end

  defp run_queued_and_capture_error_log(fun) do
    job = TestQueue.enqueue(fun)
    log = capture_log(fn -> TestQueue.drain_queue() end)
    assert log =~ ~s/failed processing job id=#{job.id} in queue "test_queue"/
    log
  end

  defmodule TestQueue do
    use Oban.Worker, queue: "test_queue"

    def enqueue(fun) do
      encoded_fun = fun |> :erlang.term_to_binary() |> Base.encode64(padding: false)
      Oban.insert!(new(%{arg: encoded_fun}))
    end

    def drain_queue, do: Oban.drain_queue(queue: "test_queue")

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"arg" => arg}}) do
      fun = arg |> Base.decode64!(padding: false) |> :erlang.binary_to_term()
      fun.()
    end
  end
end
