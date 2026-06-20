defmodule Ophis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Ophis.{EventStream, GraphState, Ingest, Metrics, PubSub, Repo, Telemetry, Web}

  alias Persistence.Support

  @app :ophis

  @impl true
  def start(_type, _args) do
    AppConfig.resolve!(@app)

    own_node? = Application.get_env(@app, :own_node, false)

    if own_node? do
      Metrics.Setup.setup()
      Corsica.Telemetry.attach_default_handler(log_levels: [accepted: false, invalid: :info, rejected: :info])
    end

    # Attach to juice_rpc telemetry to auto-populate the service graph
    Telemetry.attach()

    configure_logger()

    children =
      case own_node? do
        true ->
          [
            # Core graph state (in-memory, ETS-backed)
            GraphState,

            # UDP ingest listener (port 9999)
            {Ingest, []},

            Repo,

            EventStream,
            {Phoenix.PubSub, name: PubSub, adapter_name: Phoenix.PubSub.PG2},

            Web.Endpoint,
            {PlugAttack.Storage.Ets, name: Web.Plug.RateLimit.Storage, clean_period: 60_000}
          ]
          |> add_prom_ex(Application.get_env(@app, :env))

        false ->
          []
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ophis.Supervisor]

    with {:ok, _} = result <- Supervisor.start_link(children, opts),
         {true, _} <- {own_node?, result},
         :ok <- Support.create_db(Repo),
         :ok <- Support.migrate(:up, Repo) do
      result
    else
      {false, result} -> result
      err -> err
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp add_prom_ex(children, :prod), do: [Metrics.PromEx | children]
  defp add_prom_ex(children, _), do: children

  defp configure_logger do
    # We set logger backend with JUICE_LOGGER_BACKEND during application start.
    # Can't be set in the config as logger starts before we have a chance to
    # resolve environment variables.
    replace_backend = fn new_backend, replaced_backend ->
      Logger.remove_backend(replaced_backend, flush: true)
      Logger.add_backend(new_backend)
    end

    case System.get_env("JUICE_LOGGER_BACKEND") do
      "json" -> replace_backend.(LoggerJSON, :console)
      x when x in [:"console", nil] -> replace_backend.(:console, LoggerJSON)
    end
  end
end
