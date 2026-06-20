defmodule Ophis.MixProject do
  use Mix.Project

  
  alias Ophis.{Repo, Web}
  
  
  

  def project do
    [
      app: :ophis,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_deps: :apps_direct, plt_add_apps: [:juice_rpc, :confex], ignore_warnings: ".dialyzer_ignore.exs"],
      
      name: "Ophis",
      releases: [
        ophis: fn ->
          version =
            case System.get_env("GIT_COMMIT_SHORT_SHA") do
              nil -> {:from_app, :ophis}
              x -> x
            end

          [
            version: version,
            include_executables_for: [:unix],
            applications: [opentelemetry_exporter: :temporary, opentelemetry: :temporary]
          ]
        end
      ]
      
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ophis.Application, []},
      env: config(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:accounts, "~> 0.4", organization: "juiice"},
      {:app_config, "~> 0.1", organization: "juiice"},
      {:appsignal, "~> 2.16"},
      
      {:appsignal_phoenix, "~> 2.8"},
      {:bandit, "~> 1.0"},
      
      {:common_utils, "~> 0.4", organization: "juiice"},
      {:confex, "~> 3.5.0"},
      
      {:corsica, "~> 2.1"},
      
      {:credo, "~> 1.6", runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      
      {:errand, "~> 0.1", organization: "juiice"},
      
      {:event_system, "~> 0.1", organization: "juiice"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:faker, "~> 0.18"},
      {:gettext, "~> 0.11"},
      {:http_client, "~> 0.2", organization: "juiice"},
      {:jason, "~> 1.3"},
      {:juice_rpc, "~> 0.6", organization: "juiice"},
      
      {:libcluster_strategies, "~> 0.2", organization: "juiice"},
      
      {:logger_json, "~> 7.0"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:money, "~> 1.12"},
      {:observer_cli, "~> 1.7"},
      
      {:open_api_spex, "~> 3.18"},
      
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},
      
      {:opentelemetry_bandit, "~> 0.3.0"},
      
      
      {:opentelemetry_ecto, "~> 1.2"},
      
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_logger_metadata, "~> 0.2.0"},
      
      {:opentelemetry_phoenix, "~> 2.0"},
      
      {:opentelemetry_telemetry, "~> 1.1"},
      {:patch, "~> 0.13.0", only: [:test]},
      
      {:persistence, "~> 0.5", organization: "juiice"},
      
      
      {:phoenix, "~> 1.7.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_view, "~> 2.0"},
      {:plug_attack, "~> 0.4.3"},
      
      {:prom_ex, "~> 1.11"},
      
      {:request_response_logger, "~> 0.2", organization: "juiice"},
      {:request_validator, "~> 0.8", organization: "juiice"},
      
      {:rop, "~> 0.7", organization: "juiice"},
      
      {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false},
      
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:types, "~> 0.1", organization: "juiice"},
      
      {:webhook, "~> 0.3", organization: "juiice"},
      {:websocket, "~> 0.1", organization: "juiice"},
      {:version_tasks, "~> 0.12.0"}
      
    ]
  end

  defp aliases do
    [
      compile: ~w[format compile],
      dialyzer: ["dialyzer --force-check"],
      
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      setup: ["deps.get", "ecto.setup"],
      
      lint: ["format --check-formatted", "credo --strict"],
      
      sobelow: ["sobelow -i Config.HTTPS"],
      
      test: ["test --max-failures 1"],
      publish: ["hex.publish --organization juiice --yes --replace"]
    ]
  end

  defp package do
    [
      organization: "juiice",
      description: "Ophis",
      licenses: [],
      links: %{
        "Gitlab" => "https://gitlab.com/juice4/platform/ophis"
      },
      files: ~w(lib mix.exs .formatter.exs README.md config priv)
    ]
  end

  defp config(env) do
    
    common_repo_config = [
      priv: "priv/repo",
      username: {:system, "JUICE_DB_USER"},
      password: {:system, "JUICE_DB_PASS"},
      hostname: {:system, "JUICE_DB_HOST"},
      database: {:system, "JUICE_DB_NAME"},
      ssl: {:system, :boolean, "JUICE_DB_SSL", false},
      pool_size: 2
    ]
    

    [
      {:env, env},
      {:own_node, false},
      {:deployment_env, {:system, "JUICE_ENVIRONMENT"}},
      
      {Repo, Keyword.merge(common_repo_config, repo_config(env))},
      {:ecto_repos, [Repo]},
      {:migration_repo, Repo},
      {:repo, repo_selection(env)},
      
      
      {
        Web.Endpoint,
        [
          url: [host: {:system, "HOST_NAME", "ophis.spendjuice.com"}, scheme: "https", port: 443],
          http: [port: {:system, :integer, "PORT", 4000}],
          server: false,
          adapter: Bandit.PhoenixAdapter,
          secret_key_base: {:system, "JUICE_SECRET_KEY_BASE"},
          render_errors: [view: Web.ErrorView, accepts: ~w(json), layout: false],
          pubsub_server: Ophis.PubSub,
          check_origin: false
        ]
      }
      
    ]
  end

  
  defp repo_config(:prod), do: []
  defp repo_config(:dev), do: [show_sensitive_data_on_connection_error: true]

  defp repo_config(:test),
    do: [database: {:system, "JUICE_TEST_DB_NAME"}, show_sensitive_data_on_connection_error: true]

  defp repo_selection(:test), do: Persistence.Repo
  defp repo_selection(_env), do: Repo
  
end
