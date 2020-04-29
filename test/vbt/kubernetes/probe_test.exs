defmodule VBT.Kubernetes.ProbeTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias VBT.Kubernetes.Probe

  describe "liveness" do
    test "responds with 200 on the configured liveness path" do
      conn = Probe.call(conn(:get, "/healthz"), Probe.init("/healthz"))
      assert conn.state == :set
      assert conn.status == 200
      assert conn.resp_body == ""
    end

    test "leaves connection intact on other paths" do
      in_conn = conn(:get, "/another_path")
      out_conn = Probe.call(in_conn, Probe.init("/healthz"))
      assert out_conn == in_conn
      assert out_conn.state == :unset
    end

    test "leaves connection intact if method is not get" do
      in_conn = conn(:post, "/healthz")
      out_conn = Probe.call(in_conn, Probe.init("/healthz"))
      assert out_conn == in_conn
      assert out_conn.state == :unset
    end
  end
end
