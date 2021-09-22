defmodule SkafolderTesterWeb.EndpointTest do
  use SkafolderTesterTest.Web.ConnCase, async: false
  alias SkafolderTesterTest.Web.TestPlug

  describe "alive" do
    test "returns a 200 status code in response" do
      assert %{resp_body: "", status: 200} = get(build_conn(), "/healthz")
    end
  end

  describe "exception details" do
    for release_level <- ~w/develop stage preview/ do
      test "are sent to frontend on #{release_level}" do
        error =
          cause_server_exception(release_level: unquote(release_level), message: "some error")

        assert error =~ "some error"
        assert error =~ Path.basename(__ENV__.file)
      end
    end

    for release_level <- ~w/prod CI/ do
      test "are not sent to frontend on #{release_level}" do
        error =
          cause_server_exception(release_level: unquote(release_level), message: "some error")

        assert error == "Internal Server Error"
      end
    end

    for release_level <- ~w/develop preview prod/ do
      test "are sent to sentry on #{release_level}" do
        capture_sentry_events()
        cause_server_exception(release_level: unquote(release_level), message: "some error")
        assert_receive {:sentry_report, body}
        assert Map.fetch!(Jason.decode!(body), "message") =~ "(RuntimeError some error)"
      end
    end
  end

  defp capture_sentry_events do
    test_pid = self()
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:sentry_report, body})
      Plug.Conn.resp(conn, 200, ~s<{"id": "340"}>)
    end)

    Application.put_env(:sentry, :dsn, "http://public:secret@localhost:#{bypass.port}/1")
    Application.put_env(:sentry, :send_result, :sync)
  end

  defp cause_server_exception(opts) do
    prev_release_level = set_release_level(Keyword.get(opts, :release_level))

    try do
      {500, _headers, body} = assert_error_sent(500, fn -> dispatch(opts) end)

      body
      |> Jason.decode!()
      |> Map.fetch!("errors")
      |> hd()
      |> Map.fetch!("message")
    after
      set_release_level(prev_release_level)
    end
  end

  defp dispatch(opts),
    do: TestPlug.dispatch(fn _conn -> raise Keyword.fetch!(opts, :message) end)

  defp set_release_level(value) do
    current_release_level = System.get_env("RELEASE_LEVEL")

    if is_nil(value),
      do: System.delete_env("RELEASE_LEVEL"),
      else: System.put_env("RELEASE_LEVEL", value)

    current_release_level
  end
end
