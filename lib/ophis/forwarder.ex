defmodule Ophis.Forwarder do
  @moduledoc """
  Drop-in telemetry forwarder for any Juice service that uses `juice_rpc`.

  Attaches to `[:rpc, :request, :stop]` and `[:rpc, :request, :exception]`
  telemetry spans and forwards them as UDP datagrams to the ophis collector.

  ## Usage

  1. Add `ophis` to your service's deps:
         {:ophis, "~> 0.1", organization: "juiice"}

  2. Add to your application supervision tree:
         {Ophis.Forwarder, [collector_port: 9999]}

  No other changes needed. Every `JuiceRpc.call/4` from this service
  will appear on the ophis dashboard automatically.
  """

  use GenServer
  require Logger

  @default_collector_addr {127, 0, 0, 1}
  @default_collector_port 9999
  @heartbeat_interval :timer.seconds(10)

  # ── Public API ────────────────────────────────────────────────────

  @doc """
  Start the forwarder.

  Options:
    - `:collector_ip` — IP tuple for the ophis host (default: `{127, 0, 0, 1}`)
    - `:collector_port` — UDP port for ophis ingest (default: `9999`)
    - `:service_name` — override the reported service name (default: OTP app name)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ── GenServer callbacks ───────────────────────────────────────────

  @impl true
  def init(opts) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])

    collector_addr = Keyword.get(opts, :collector_ip, @default_collector_addr)
    collector_port = Keyword.get(opts, :collector_port, @default_collector_port)
    service_name = Keyword.get(opts, :service_name, default_service_name())

    :telemetry.attach_many(
      "ophis-forwarder-#{service_name}",
      [
        [:rpc, :request, :stop],
        [:rpc, :request, :exception]
      ],
      &__MODULE__.handle_telemetry/4,
      self()
    )

    schedule_heartbeat()

    Logger.info(
      "Ophis forwarder started — forwarding to #{inspect(collector_addr)}:#{collector_port} as #{service_name}"
    )

    {:ok,
     %{
       socket: socket,
       collector_addr: collector_addr,
       collector_port: collector_port,
       service_name: service_name
     }}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    send_event(state, %{type: "heartbeat", service: state.service_name, status: "healthy"})
    schedule_heartbeat()
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    # Telemetry callback relayed via send/2 from handle_telemetry/4
    case msg do
      {:telemetry, event, measurements, metadata} ->
        handle_telemetry_msg(event, measurements, metadata, state)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  # ── Telemetry callback (runs in telemetry process — relay to GenServer) ──

  @doc false
  def handle_telemetry(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  # ── Message handlers ──────────────────────────────────────────────

  defp handle_telemetry_msg([:rpc, :request, :stop], measurements, metadata, state) do
    status = if Map.has_key?(metadata, :error), do: "error", else: "ok"
    send_rpc_call(state, measurements, metadata, status)
  end

  defp handle_telemetry_msg([:rpc, :request, :exception], measurements, metadata, state) do
    send_rpc_call(state, measurements, metadata, "error")
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp send_rpc_call(state, measurements, metadata, status) do
    duration_ms =
      measurements
      |> Map.get(:duration, 0)
      |> then(&System.convert_time_unit(&1, :native, :millisecond))

    send_event(state, %{
      type: "rpc_call",
      source: source_name(metadata, state.service_name),
      target: target_name(metadata),
      duration_ms: duration_ms,
      status: status,
      trace_id: ""
    })
  end

  defp send_event(state, payload) do
    :gen_udp.send(
      state.socket,
      state.collector_addr,
      state.collector_port,
      Jason.encode!(payload)
    )
  rescue
    err -> Logger.warning("Ophis forwarder failed: #{inspect(err)}")
  end

  # source = calling service (otp_app from juice_rpc metadata)
  defp source_name(%{otp_app: app}, _default) when not is_nil(app), do: to_string(app)
  defp source_name(_, default), do: default

  # target = called service
  defp target_name(%{service: svc}) when not is_nil(svc), do: to_string(svc)

  defp target_name(%{mfa: {mod, _fun, _arity}}) when not is_nil(mod) do
    mod
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".")
    |> hd()
    |> Macro.underscore()
  end

  defp target_name(_), do: "unknown"

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp default_service_name do
    Application.get_env(:ophis, :service_name, to_string(node()))
  end
end
