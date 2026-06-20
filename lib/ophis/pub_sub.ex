defmodule Ophis.PubSub do
  @moduledoc """
  PubSub server name for ophis internal broadcasts.

  Used as the registration name for Phoenix.PubSub in the supervision tree,
  and referenced by GraphState, GraphChannel, and Telemetry for graph update
  notifications.
  """
end
