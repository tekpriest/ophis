import Config

config :gen_rpc,
  port_discovery: :manual,
  tcp_server_port: "RPC_PORT" |> System.get_env("6000") |> Integer.parse() |> elem(0)

url = System.get_env("JUICE_OTLP_URL", "http://tempo.monitoring.svc.cluster.local:4318")

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{endpoints: [url]}}
  }

config :opentelemetry_exporter, otlp_endpoint: url
