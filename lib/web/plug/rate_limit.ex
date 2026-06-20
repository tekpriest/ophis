defmodule Ophis.Web.Plug.RateLimit do
  @moduledoc false

  use PlugAttack
  import Plug.Conn

  rule "allow localhost requests", conn do
    allow conn.remote_ip == {127, 0, 0, 1}
  end

  rule "2 reqs/second", conn do
    throttle(conn.remote_ip, period: 60_000, limit: 120, storage: {PlugAttack.Storage.Ets, __MODULE__.Storage})
  end

  def allow_action(conn, {:throttle, data}, opts) do
    conn
    |> add_headers(data)
    |> allow_action(true, opts)
  end

  def allow_action(conn, _data, _opts), do: conn

  def block_action(conn, {:throttle, data}, opts) do
    conn
    |> add_headers(data)
    |> block_action(false, opts)
  end

  def block_action(conn, _data, _opts) do
    conn
    |> send_resp(:too_many_requests, Jason.encode!(%{message: "Too Many Requests"}))
    |> halt()
  end

  defp add_headers(conn, data) do
    # The expires_at value is a unix time in milliseconds, we want to return one in seconds
    reset = div(data[:expires_at], 1_000)

    conn
    |> put_resp_header("x-ratelimit-limit", to_string(data[:limit]))
    |> put_resp_header("x-ratelimit-remaining", to_string(data[:remaining]))
    |> put_resp_header("x-ratelimit-reset", to_string(reset))
  end
end
