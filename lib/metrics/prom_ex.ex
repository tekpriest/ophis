defmodule Ophis.Metrics.PromEx do
  @moduledoc false

  
  alias Ophis.{Repo, Web}
  
  
  
  alias PromEx.Plugins

  @app :ophis

  use PromEx, otp_app: @app

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      
      {Plugins.Phoenix, router: Web.Router, endpoint: Web.Endpoint},
      
      
      {Plugins.Ecto, otp_app: @app, repos: [Repo]}
      
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      default_selected_interval: "1m",
      datasource_id: "Prometheus"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      
      {:prom_ex, "phoenix.json"},
      
      
      {:prom_ex, "ecto.json"}
      
    ]
  end
end
