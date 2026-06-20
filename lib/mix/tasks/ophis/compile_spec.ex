defmodule Mix.Tasks.Ophis.CompileSpec do
  @moduledoc "Compiles ophis API spec"
  @shortdoc "Compiles ophis API spec"

  alias Ophis.Web.{Endpoint, Spec}

  use Mix.Task

  def run(_) do
    Confex.resolve_env!(:ophis)
    Endpoint.start_link()

    Spec.spec()
    |> Jason.encode!(pretty: true, maps: :strict)
    |> (&File.write!("openapi.json", &1)).()
  end
end
