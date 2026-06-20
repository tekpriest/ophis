defmodule Ophis.IngestTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _pid} = start_supervised({Ophis.GraphState, []})
    :ok
  end

  describe "apply_event/1" do
    test "applies rpc_call event to graph state" do
      event = %Ophis.IngestEvent{
        type: :rpc_call,
        source: "accounts",
        target: "ledger",
        duration_ms: 55,
        status: "ok",
        trace_id: ""
      }

      Ophis.Ingest.apply_event(event)

      %{nodes: nodes, edges: edges} = Ophis.GraphState.snapshot()

      assert length(nodes) == 2
      assert Enum.any?(nodes, &(&1.id == "accounts"))
      assert Enum.any?(nodes, &(&1.id == "ledger"))
      assert length(edges) == 1
    end

    test "applies heartbeat event to graph state" do
      event = %Ophis.IngestEvent{
        type: :heartbeat,
        service: "binance",
        status: "ok"
      }

      Ophis.Ingest.apply_event(event)

      %{nodes: nodes} = Ophis.GraphState.snapshot()
      assert Enum.any?(nodes, &(&1.id == "binance"))
    end

    test "rpc_call with error status records error" do
      event = %Ophis.IngestEvent{
        type: :rpc_call,
        source: "src",
        target: "tgt",
        duration_ms: 100,
        status: "timeout",
        trace_id: ""
      }

      Ophis.Ingest.apply_event(event)

      %{edges: edges} = Ophis.GraphState.snapshot()
      edge = hd(edges)
      assert edge.error_rate > 0.0
    end
  end
end
