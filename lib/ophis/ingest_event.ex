defmodule Ophis.IngestEvent do
  @moduledoc """
  Wire format pushed by connectors (Elixir telemetry forwarder, future Go/Node connectors, etc).

  Mirror of the Rust `IngestEvent` enum — same schema, same `type` tag for JSON dispatch.
  """

  @type t :: %__MODULE__{
          type: :rpc_call | :heartbeat,
          source: String.t() | nil,
          target: String.t() | nil,
          duration_ms: non_neg_integer() | nil,
          status: String.t() | nil,
          service: String.t() | nil,
          trace_id: String.t() | nil
        }

  defstruct [:type, :source, :target, :duration_ms, :status, :service, :trace_id]

  @doc "Parse a decoded JSON map into an IngestEvent struct."
  @spec from_map(map()) :: {:ok, t()} | {:error, :invalid_type}
  def from_map(%{"type" => "rpc_call"} = m) do
    {:ok,
     %__MODULE__{
       type: :rpc_call,
       source: m["source"],
       target: m["target"],
       duration_ms: m["duration_ms"],
       status: m["status"],
       trace_id: m["trace_id"] || ""
     }}
  end

  def from_map(%{"type" => "heartbeat"} = m) do
    {:ok,
     %__MODULE__{
       type: :heartbeat,
       service: m["service"],
       status: m["status"] || ""
     }}
  end

  def from_map(%{"type" => _}), do: {:error, :invalid_type}
  def from_map(_), do: {:error, :invalid_type}
end
