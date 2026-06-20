defmodule Ophis.Web.Plug.MetricsExporter do
  @moduledoc false

  alias Ophis.Metrics
  import Plug.Conn

  @path "/metrics"

  def init(opts), do: opts

  def call(%{request_path: @path, method: "GET"} = conn, _opts) do
    case authenticated?(conn) do
      false -> conn
      true -> PromEx.Plug.call(conn, %{prom_ex_module: Metrics.PromEx, metrics_path: @path})
    end
  end

  def call(conn, _), do: conn

  defp authenticated?(conn) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> Kernel.==(Metrics.Setup.prometheus_header())
  end
end
