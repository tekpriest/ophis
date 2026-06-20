defmodule Ophis.Metrics.Setup do
  @moduledoc false
  require Logger

  @app :ophis

  def setup do
    Logger.info("Setup `ophis` metrics")
    @app |> Application.get_env(:env) |> setup_telemetry()
    compute_prometheus_header()
  end

  def prometheus_header, do: Application.get_env(@app, :prometheus_header)

  defp setup_telemetry(:prod) do
    OpentelemetryLoggerMetadata.setup()

    @app
    |> Application.get_env(:repo)
    |> then(& &1.config())
    |> Keyword.get(:telemetry_prefix, [@app, :repo])
    |> OpentelemetryEcto.setup(db_statement: :enabled)

    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
  end

  defp setup_telemetry(_), do: :ok

  defp compute_prometheus_header do
    # This way we don't need to do it on every request
    user = Application.get_env(@app, :prometheus_user)
    pass = Application.get_env(@app, :prometheus_password)
    Application.put_env(@app, :prometheus_header, "Basic #{Base.encode64("#{user}:#{pass}")}")
  end
end
