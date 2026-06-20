import Config


alias Ophis.{Repo, Web}




config :juice_rpc, env: config_env()
config :accounts, env: config_env(), own_node: config_env() == :test

config :webhook, env: config_env(), own_node: false
config :websocket, env: config_env(), own_node: false


config :ophis,
  
  env: config_env(),
  
  
  ecto_repos: [Repo],
  migration_repo: Repo,
  repo: Repo,
  
  
  own_node: true,
  deployment_env: {:system, "JUICE_ENVIRONMENT"},
  prometheus_user: {:system, "PROMETHEUS_USER", ""},
  prometheus_password: {:system, "PROMETHEUS_PASS", ""}
  


config :ophis, Web.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: {:system, "HOST_NAME", "ophis.spendjuice.com"}, scheme: "https", port: 443],
  http: [
    port: {:system, :integer, "PORT", 4000},
    websocket_options: [compress: false],
    thousand_island_options: [read_timeout: 10_000, shutdown_timeout: 5_000],
    http_1_options: [max_header_length: 1100, max_request_line_length: 5_000, max_header_count: 30]
  ],
  server: {:system, :boolean, "START_SERVER", true},
  secret_key_base: {:system, "JUICE_SECRET_KEY_BASE"},
  render_errors: [view: Web.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Ophis.PubSub,
  check_origin: false

config :phoenix, :json_library, Jason
config :mime, :types, %{}
config :request_validator, strict: true



config :errand,
  supervisor: Ophis.ErrandSupervisor,
  tasks: [startup: {:once, {{:duration, {10, :s}}, {IO, :puts, ["ophis started"]}, [app_dependencies: [:ophis]]}}]



config :ophis, Repo,
  priv: "priv/repo",
  username: {:system, "JUICE_DB_USER"},
  password: {:system, "JUICE_DB_PASS"},
  database: {:system, "JUICE_DB_NAME"},
  hostname: {:system, "JUICE_DB_HOST"},
  ssl: {:system, :boolean, "JUICE_DB_SSL", false},
  pool_size: 2

config :persistence, env: config_env()


config :http_client, env: config_env()

config :money,
  default_currency: :USD,
  custom_currencies: [
    BTC: %{name: "Bitcoin", symbol: "₿", exponent: 8},
    ETH: %{name: "Ethereum", symbol: "ETH", exponent: 18},
    BUSD: %{name: "Binance USD", symbol: "BUSD", exponent: 2},
    USDT: %{name: "USD Token", symbol: "USDT", exponent: 2},
    USDC: %{name: "USD Coin", symbol: "USDC", exponent: 2}
  ]

config :opentelemetry,
  resource: [service: %{name: "ophis"}],
  span_processor: :batch,
  traces_exporter: :otlp

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: :all,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger_json, :backend,
  metadata: :all,
  json_encoder: Jason,
  formatter: LoggerJSON.Formatters.DatadogLogger

import_config "#{config_env()}.exs"
