defmodule Ophis.Telemetry do
  @moduledoc """
  Attaches to juice_rpc's `[:rpc, :request]` telemetry events to
  auto-populate the service graph.

  No separate forwarder needed — ophis runs inside the BEAM cluster
  and receives telemetry directly from any service using `JuiceRpc.call/4`
  (the gen_rpc path).
  """

  alias Ophis.{GraphState, PubSub}

  require Logger

  @rpc_event [:rpc, :request, :stop]

  # ── Public API ────────────────────────────────────────────────────

  @doc """
  Attach the telemetry handler. Idempotent — safe to call multiple times.

  Should be called during application startup before the supervision tree
  starts making RPC calls.
  """
  @spec attach() :: :ok
  def attach do
    case :telemetry.attach("ophis-rpc-ingest", @rpc_event, &handle_rpc_stop/4, nil) do
      :ok ->
        Logger.info("Attached telemetry handler to #{inspect(@rpc_event)}")
        :ok

      {:error, :already_exists} ->
        Logger.debug("Telemetry handler already attached — skipping")
        :ok
    end
  end

  @doc "Detach the handler. Used in tests."
  @spec detach() :: :ok | {:error, :not_found}
  def detach do
    :telemetry.detach("ophis-rpc-ingest")
  end

  # ── Callbacks ─────────────────────────────────────────────────────

  def handle_rpc_stop(_event, _measurements, metadata, _config) do
    with {:ok, source} <- extract_source(metadata),
         {:ok, target} <- extract_target(metadata),
         {:ok, duration_ms} <- extract_duration(metadata),
         {:ok, ok} <- extract_status(metadata) do
      GraphState.record_call(source, target, duration_ms, ok)
      PubSub.broadcast(Ophis.PubSub, "graph:update", :updated)
    end

    :ok
  end

  # ── Metadata extraction ──────────────────────────────────────────

  # source = the service making the call (otp_app in metadata)
  defp extract_source(%{otp_app: app}) when is_atom(app) and app != nil,
    do: {:ok, Atom.to_string(app)}

  defp extract_source(_), do: :error

  # target = the destination service
  defp extract_target(%{service: svc}) when is_atom(svc) and svc != nil,
    do: {:ok, Atom.to_string(svc)}

  defp extract_target(%{mfa: {mod, _fun, _arity}}) when is_atom(mod) do
    # Fallback: extract service from target module name (e.g. Elixir.Accounts.Rpc -> accounts)
    mod
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".")
    |> List.first()
    |> case do
      nil -> :error
      name -> {:ok, Macro.underscore(name)}
    end
  end

  defp extract_target(_), do: :error

  # duration from telemetry metadata (microseconds, convert to ms)
  defp extract_duration(%{duration: dur}) when is_integer(dur) and dur > 0,
    do: {:ok, div(dur, 1000)}

  defp extract_duration(_), do: :error

  # status: ok if the result tuple is {:ok, _}, error otherwise
  defp extract_status(%{result: {:ok, _}}), do: {:ok, true}
  defp extract_status(%{result: :ok}), do: {:ok, true}
  defp extract_status(_), do: {:ok, false}
end
