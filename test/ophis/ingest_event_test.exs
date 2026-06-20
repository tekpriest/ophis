defmodule Ophis.IngestEventTest do
  use ExUnit.Case, async: true

  describe "from_map/1" do
    test "parses rpc_call event" do
      {:ok, event} =
        Ophis.IngestEvent.from_map(%{
          "type" => "rpc_call",
          "source" => "accounts",
          "target" => "fireblocks",
          "duration_ms" => 42,
          "status" => "ok",
          "trace_id" => "abc123"
        })

      assert event.type == :rpc_call
      assert event.source == "accounts"
      assert event.target == "fireblocks"
      assert event.duration_ms == 42
      assert event.status == "ok"
      assert event.trace_id == "abc123"
    end

    test "parses rpc_call without optional trace_id" do
      {:ok, event} =
        Ophis.IngestEvent.from_map(%{
          "type" => "rpc_call",
          "source" => "a",
          "target" => "b",
          "duration_ms" => 10,
          "status" => "error"
        })

      assert event.trace_id == ""
    end

    test "parses heartbeat event" do
      {:ok, event} =
        Ophis.IngestEvent.from_map(%{
          "type" => "heartbeat",
          "service" => "ledger",
          "status" => "alive"
        })

      assert event.type == :heartbeat
      assert event.service == "ledger"
      assert event.status == "alive"
    end

    test "returns error for unknown type" do
      assert Ophis.IngestEvent.from_map(%{"type" => "unknown"}) == {:error, :invalid_type}
    end

    test "returns error for missing type" do
      assert Ophis.IngestEvent.from_map(%{"source" => "x"}) == {:error, :invalid_type}
    end
  end
end
