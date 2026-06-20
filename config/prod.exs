import Config

config :appsignal, :config, active: true

config :logger,
  level: :info,
  truncate: :infinity,
  compile_time_purge_matching: [
    [level_lower_than: :info],
    [library: :k8s]
  ]

config :ophis, Ophis.Metrics.PromEx,
  manual_metrics_start_delay: :no_delay,
  grafana: [
    host: {:system, "GRAFANA_HOST", "http://dummy.host"},
    auth_token: {:system, "GRAFANA_TOKEN", ""},
    folder_name: "ophis",
    annotate_app_lifecycle: true
  ]

config :phoenix, logger: false
