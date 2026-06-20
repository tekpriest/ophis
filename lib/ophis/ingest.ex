defmodule Ophis.Ingest do
  @moduledoc """
  UDP ingest listener and shared event-apply logic.

  Listens on a UDP port for JSON-encoded IngestEvent messages from
  connectors (Elixir telemetry forwarders, etc). Also provides the
  shared `apply_event/2` function used by the HTTP ingest endpoint.
  """

  alias Ophis.{GraphState, IngestEvent}

  require Logger

  @default_port 9999
  @buffer_size 4096

  # ── Public API ────────────────────────────────────────────────────

  @doc """
  Start the UDP ingest listener as a linked Task.

  Returns the task PID. The task loops forever, decoding JSON datagrams
  and forwarding them to GraphState.
  """
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)
    Task.start_link(fn -> listen(port) end)
  end

  @doc """
  Apply a single ingest event to the graph state.

  Shared by both the UDP listener and the HTTP `/ingest` endpoint.
  """
  @spec apply_event(IngestEvent.t()) :: :ok
  def apply_event(%IngestEvent{type: :rpc_call} = event) do
    ok = event.status == "ok"
    GraphState.record_call(event.source, event.target, event.duration_ms, ok)
  end

  def apply_event(%IngestEvent{type: :heartbeat} = event) do
    GraphState.touch_node(event.service)
  end

  # ── Private ───────────────────────────────────────────────────────

  defp listen(port) do
    Logger.info("Ingest UDP listener starting on port #{port}")

    {:ok, socket} = :gen_udp.open(port, [:binary, active: true, reuseaddr: true])

    loop(socket)
  end

  defp loop(socket) do
    receive do
      {:udp, _socket, _src_ip, _src_port, payload} ->
        handle_datagram(payload)
        loop(socket)

      other ->
        Logger.warning("Ingest UDP received unexpected message: #{inspect(other)}")
        loop(socket)
    end
  end

  defp handle_datagram(payload) do
    case Jason.decode(payload) do
      {:ok, map} ->
        case IngestEvent.from_map(map) do
          {:ok, event} ->
            apply_event(event)

          {:error, reason} ->
            Logger.warning("Ingest UDP dropped invalid event (#{byte_size(payload)} bytes): #{reason}")
        end

      {:error, err} ->
        Logger.warning("Ingest UDP dropped malformed JSON (#{byte_size(payload)} bytes): #{inspect(err)}")
    end
  end
end
