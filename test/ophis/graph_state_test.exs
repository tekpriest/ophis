defmodule Ophis.GraphStateTest do
  use ExUnit.Case, async: true

  setup do
    # Start GraphState with a unique name to avoid test collisions
    {:ok, pid} = start_supervised({Ophis.GraphState, []})
    {:ok, pid: pid}
  end

  describe "touch_node/1" do
    test "creates a new node as healthy" do
      Ophis.GraphState.touch_node("accounts")

      %{nodes: nodes} = Ophis.GraphState.snapshot()
      assert length(nodes) == 1

      node = Enum.find(nodes, &(&1.id == "accounts"))
      assert node.status == :healthy
      assert node.error_rate == 0.0
      assert node.call_count == 0
    end

    test "touching an unknown node makes it healthy again" do
      Ophis.GraphState.touch_node("fireblocks")

      # Manually set it to unknown (simulating sweep)
      :ets.insert(:ophis_nodes, {"fireblocks", %{status: :unknown, last_seen: 0, error_rate: 0.0, call_count: 0}})

      # Touch should bring it back
      Ophis.GraphState.touch_node("fireblocks")

      %{nodes: nodes} = Ophis.GraphState.snapshot()
      node = Enum.find(nodes, &(&1.id == "fireblocks"))
      assert node.status == :healthy
    end
  end

  describe "record_call/4" do
    test "creates source and target nodes and an edge" do
      Ophis.GraphState.record_call("accounts", "fireblocks", 42, true)

      %{nodes: nodes, edges: edges} = Ophis.GraphState.snapshot()

      assert length(nodes) == 2
      assert length(edges) == 1

      source = Enum.find(nodes, &(&1.id == "accounts"))
      target = Enum.find(nodes, &(&1.id == "fireblocks"))
      edge = hd(edges)

      assert source.call_count == 1
      assert target.call_count == 0
      assert edge.source == "accounts"
      assert edge.target == "fireblocks"
      assert edge.call_count == 1
      assert edge.avg_ms == 42.0
      assert edge.error_rate == 0.0
    end

    test "error calls increase error rate on source node" do
      # 5 calls, 2 errors
      Ophis.GraphState.record_call("binance", "ledger", 10, true)
      Ophis.GraphState.record_call("binance", "ledger", 20, true)
      Ophis.GraphState.record_call("binance", "ledger", 30, false)
      Ophis.GraphState.record_call("binance", "ledger", 40, true)
      Ophis.GraphState.record_call("binance", "ledger", 50, false)

      %{nodes: nodes} = Ophis.GraphState.snapshot()
      source = Enum.find(nodes, &(&1.id == "binance"))

      assert source.call_count == 5

      # EMA with alpha=0.2: each error contributes 0.2, each ok 0.0
      # After 5 calls: see implementation for precise value
      assert source.error_rate > 0.0
      assert source.error_rate < 1.0
    end

    test "node becomes degraded when error rate exceeds threshold" do
      # Push error rate above 0.2 threshold
      for _ <- 1..10 do
        Ophis.GraphState.record_call("providus", "ledger", 10, false)
      end

      %{nodes: nodes} = Ophis.GraphState.snapshot()
      source = Enum.find(nodes, &(&1.id == "providus"))
      assert source.status == :degraded
    end

    test "multiple calls aggregate edge stats" do
      Ophis.GraphState.record_call("webhook", "notification", 100, true)
      Ophis.GraphState.record_call("webhook", "notification", 200, true)
      Ophis.GraphState.record_call("webhook", "notification", 300, false)

      %{edges: edges} = Ophis.GraphState.snapshot()
      edge = hd(edges)

      assert edge.call_count == 3
      assert edge.avg_ms == 200.0
      assert edge.error_rate == Float.round(1.0 / 3.0, 4)
    end
  end

  describe "snapshot/0" do
    test "returns empty graph when no data" do
      assert Ophis.GraphState.snapshot() == %{nodes: [], edges: []}
    end

    test "returns JSON-compatible structure" do
      Ophis.GraphState.touch_node("test-svc")

      snapshot = Ophis.GraphState.snapshot()
      assert is_map(snapshot)
      assert is_list(snapshot.nodes)
      assert is_list(snapshot.edges)

      # Verify can be JSON-encoded
      {:ok, _} = Jason.encode(snapshot)
    end
  end
end
