defmodule Ophis.Web.GraphSocket do
  @moduledoc """
  Raw WebSocket handler for the browser dashboard.

  On connect: subscribes to graph updates via PubSub, pushes current snapshot.
  On graph update: pushes new snapshot (debounced 200ms).
  Sends WebSocket pings every 15s.

  Uses `WebSock` behaviour — works as a raw WebSocket with zero protocol
  overhead so the existing force-graph frontend works unchanged.
  """

  alias Ophis.{GraphState, PubSub}

  @behaviour WebSock

  @debounce_ms 200

  # ── WebSock callbacks ─────────────────────────────────────────────

  @impl true
  def init(_args) do
    # Subscribe to graph updates
    Phoenix.PubSub.subscribe(PubSub, "graph:update")

    # Start ping timer every 15s (matches Rust version)
    :timer.send_interval(15_000, :ping)

    # Send initial snapshot
    send(self(), :send_snapshot)

    state = %{debounce_timer: nil}
    {:ok, state}
  end

  @impl true
  def handle_in({_text, [opcode: :text]}, state) do
    # Ignore client messages (the frontend only reads, never writes)
    {:ok, state}
  end

  @impl true
  def handle_in(_other, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(:send_snapshot, state) do
    json = snapshot_json()
    {:push, {:text, json}, state}
  end

  @impl true
  def handle_info(:debounced_snapshot, state) do
    json = snapshot_json()
    {:push, {:text, json}, %{state | debounce_timer: nil}}
  end

  @impl true
  def handle_info(:ping, state) do
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(%{topic: "graph:update"}, state) do
    # Debounce: cancel pending timer, set new one
    if state.debounce_timer, do: Process.cancel_timer(state.debounce_timer)
    timer = Process.send_after(self(), :debounced_snapshot, @debounce_ms)
    {:ok, %{state | debounce_timer: timer}}
  end

  @impl true
  def handle_info(_other, state) do
    {:ok, state}
  end

  @impl true
  def handle_control({:ping, _}, state) do
    {:ok, state}
  end

  def handle_control(:pong, state) do
    {:ok, state}
  end

  def handle_control(_other, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel any pending debounce timer
    if state && state.debounce_timer, do: Process.cancel_timer(state.debounce_timer)
    :ok
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp snapshot_json do
    GraphState.snapshot() |> Jason.encode!()
  end
end
