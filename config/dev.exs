import Config

config :ophis, Ophis.Web.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.NoneCache

config :ophis, Ophis.Repo, show_sensitive_data_on_connection_error: true
