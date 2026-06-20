defmodule Ophis.Web.Endpoint do
  @moduledoc false

  alias Ophis.{Metrics, Web}

  @app :ophis

  use Phoenix.Endpoint, otp_app: @app

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_ophis_key",
    signing_salt: "r72l1984"
  ]

  plug PromEx.Plug, prom_ex_module: Metrics.PromEx

  socket "/socket", Web.Socket, websocket: true, longpoll: false

  # Handle health checks
  plug CommonUtils.Plug.Health, app: @app
  plug CommonUtils.Plug.Ping
  plug CommonUtils.Plug.LogRemoteIP

  plug Corsica,
    origins: "*",
    allow_credentials: true,
    allow_headers: ~w(accept accept-language authorization content-type idempotency-key responsetype x-account-id),
    allow_methods: ~w(HEAD GET POST),
    max_age: 86400

  plug Web.Plug.RateLimit

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: @app,
    gzip: false,
    only: Web.static_paths(),
    index_file: "index.html"

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Web.Router
end
