import Config

config :logger, level: :warning

config :ophis, Ophis.Repo,
  database: {:system, "JUICE_TEST_DB_NAME"},
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true

config :ophis, repo: Persistence.Repo
