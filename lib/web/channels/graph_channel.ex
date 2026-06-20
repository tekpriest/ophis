defmodule Ophis.Web.GraphChannel do
  @moduledoc """
  Phoenix Channel for the browser dashboard.

  On join: pushes the current graph snapshot.
  On graph update (PubSub): pushes a new snapshot (debounced 200ms).
  """

  alias Ophis.{GraphState, PubSub}

  use Ophis.Web, :channel

  @debounce_ms 200

  @impl true
  def join("graph:live", _payload, socket) do
    # Subscribe to graph updates
    Phoenix.PubSub.subscribe(PubSub, "graph:update")

    # Send initial snapshot
    send(self(), :push_snapshot)

    {:ok, socket}
  end

  @impl true
  def handle_info(:push_snapshot, socket) do
    push_snapshot(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:debounced_snapshot, socket) do
    push_snapshot(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:updated, socket) do
    # Debounce: drain queued updates, push one snapshot
    if socket.assigns[:debounce_timer], do: Process.cancel_timer(socket.assigns.debounce_timer)
    timer = Process.send_after(self(), :debounced_snapshot, @debounce_ms)
    {:noreply, assign(socket, :debounce_timer, timer)}
  end

  @impl true
  def handle_info(%{topic: "graph:update"}, socket) do
    # Same debounce for map-form broadcasts (backward compat)
    handle_info(:updated, socket)
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp push_snapshot(socket) do
    snapshot = GraphState.snapshot()
    {:ok, json} = Jason.encode(snapshot)

    push(socket, "snapshot", %{data: json})
  end
end
