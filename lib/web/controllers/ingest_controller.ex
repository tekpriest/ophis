defmodule Ophis.Web.IngestController do
  @moduledoc """
  HTTP ingest endpoint — same event schema as the UDP listener.

  For tools that can't easily send UDP (Postman, browser, serverless).
  Mirror of the Rust `ingest_handler` in main.rs.
  """

  alias Ophis.{Ingest, IngestEvent}

  use Ophis.Web, :controller

  @doc """
  POST /ingest

  Accepts JSON body with the IngestEvent schema:
    {"type": "rpc_call", "source": "...", "target": "...", "duration_ms": N, "status": "ok"}
    {"type": "heartbeat", "service": "..."}
  """
  def ingest(conn, %{"type" => _} = params) do
    case IngestEvent.from_map(params) do
      {:ok, event} ->
        Ingest.apply_event(event)
        conn |> put_status(202) |> json(%{accepted: true})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: "invalid event: #{reason}"})
    end
  end

  def ingest(conn, _params) do
    conn |> put_status(422) |> json(%{error: "missing type field"})
  end
end
