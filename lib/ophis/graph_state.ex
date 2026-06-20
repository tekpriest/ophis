defmodule Ophis.GraphState do
  @moduledoc """
  In-memory graph state tracking service nodes and RPC call edges.

  Uses ETS for lock-free snapshot reads and a GenServer for serialised writes.
  Mirror of the Rust `state.rs` — same data model, same snapshot shape.
  """

  alias Ophis.PubSub

  use GenServer

  @node_table :ophis_nodes
  @edge_table :ophis_edges
  @sweep_interval_ms 10_000
  @stale_after_ms 30_000
  @error_ema_alpha 0.2
  @degraded_threshold 0.2

  # ── Public API ────────────────────────────────────────────────────

  @doc "Start the GraphState GenServer. Creates ETS tables."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Record a heartbeat from a service node."
  def touch_node(service) when is_binary(service) do
    GenServer.cast(__MODULE__, {:touch_node, service})
  end

  @doc """
  Record an RPC call from source to target.

  * `source` — calling service name
  * `target` — called service name
  * `duration_ms` — call duration in milliseconds
  * `ok` — true if successful, false if errored
  """
  def record_call(source, target, duration_ms, ok \\ true)
      when is_binary(source) and is_binary(target) and is_integer(duration_ms) do
    GenServer.cast(__MODULE__, {:record_call, source, target, duration_ms, ok})
  end

  @doc """
  Return a full graph snapshot (nodes + edges) suitable for JSON serialisation.

  Reads ETS directly — no GenServer call, safe for concurrent websocket clients.
  """
  @spec snapshot() :: %{nodes: [map()], edges: [map()]}
  def snapshot do
    nodes =
      @node_table
      |> :ets.tab2list()
      |> Enum.map(fn {id, health} ->
        %{
          id: id,
          status: health.status,
          error_rate: health.error_rate,
          call_count: health.call_count
        }
      end)

    edges =
      @edge_table
      |> :ets.tab2list()
      |> Enum.map(fn {{source, target}, stats} ->
        avg_ms = if stats.call_count > 0, do: stats.total_duration_ms / stats.call_count, else: 0.0
        error_rate = if stats.call_count > 0, do: stats.error_count / stats.call_count, else: 0.0

        %{
          source: source,
          target: target,
          call_count: stats.call_count,
          error_rate: round_float(error_rate),
          avg_ms: round_float(avg_ms)
        }
      end)

    %{nodes: nodes, edges: edges}
  end

  # ── GenServer callbacks ───────────────────────────────────────────

  @impl true
  def init(_opts) do
    @node_table = :ets.new(@node_table, [:set, :public, :named_table])
    @edge_table = :ets.new(@edge_table, [:set, :public, :named_table])

    schedule_sweep()

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:touch_node, service}, state) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@node_table, service) do
      [{^service, health}] ->
        new_health = %{health | last_seen: now}
        if health.status == :unknown, do: new_health = %{new_health | status: :healthy}
        :ets.insert(@node_table, {service, new_health})

      [] ->
        :ets.insert(@node_table, {service, default_node_health(now)})
    end

    broadcast_update()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_call, source, target, duration_ms, ok}, state) do
    now = System.monotonic_time(:millisecond)

    # Touch target
    touch_node_ets(target, now)

    # Record edge
    edge_key = {source, target}
    edge =
      case :ets.lookup(@edge_table, edge_key) do
        [{^edge_key, existing}] -> existing
        [] -> default_edge_stats()
      end

    edge = %{
      edge
      | call_count: edge.call_count + 1,
        total_duration_ms: edge.total_duration_ms + duration_ms
    }

    edge = if !ok, do: %{edge | error_count: edge.error_count + 1}, else: edge
    :ets.insert(@edge_table, {edge_key, edge})

    # Touch source and update its health
    source_health =
      case :ets.lookup(@node_table, source) do
        [{^source, health}] -> health
        [] -> default_node_health(now)
      end

    sample = if ok, do: 0.0, else: 1.0
    new_error_rate = source_health.error_rate * (1.0 - @error_ema_alpha) + sample * @error_ema_alpha

    new_status =
      cond do
        source_health.status == :down -> :down
        new_error_rate > @degraded_threshold -> :degraded
        true -> :healthy
      end

    source_health = %{
      source_health
      | last_seen: now,
        call_count: source_health.call_count + 1,
        error_rate: new_error_rate,
        status: new_status
    }

    :ets.insert(@node_table, {source, source_health})

    broadcast_update()
    {:noreply, state}
  end

  @impl true
  def handle_info(:sweep_stale, state) do
    now = System.monotonic_time(:millisecond)

    :ets.foldl(
      fn {id, health}, _acc ->
        if now - health.last_seen > @stale_after_ms and health.status != :down do
          :ets.insert(@node_table, {id, %{health | status: :unknown}})
        end
      end,
      nil,
      @node_table
    )

    schedule_sweep()
    {:noreply, state}
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp schedule_sweep do
    Process.send_after(self(), :sweep_stale, @sweep_interval_ms)
  end

  defp touch_node_ets(service, now) do
    case :ets.lookup(@node_table, service) do
      [{^service, health}] ->
        new_health = %{health | last_seen: now}
        if health.status == :unknown, do: new_health = %{new_health | status: :healthy}
        :ets.insert(@node_table, {service, new_health})

      [] ->
        :ets.insert(@node_table, {service, default_node_health(now)})
    end
  end

  defp default_node_health(now) do
    %{status: :healthy, last_seen: now, error_rate: 0.0, call_count: 0}
  end

  defp default_edge_stats do
    %{call_count: 0, error_count: 0, total_duration_ms: 0}
  end

  defp round_float(f) when is_float(f), do: Float.round(f, 4)

  defp broadcast_update do
    Phoenix.PubSub.broadcast(PubSub, "graph:update", :updated)
  rescue
    _ -> :ok
  end
end
