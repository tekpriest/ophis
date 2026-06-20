defmodule Ophis.Web.Spec do
  @moduledoc false

  alias OpenApiSpex.{Components, Info, MediaType, OpenApi, Paths, Response, Schema, SecurityScheme, Server}
  alias Ophis.Web.{Endpoint, Router}

  @behaviour OpenApi

  @app :ophis

  @impl true
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(Endpoint)],
      info: %Info{
        title: name(),
        version: version()
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}},
        responses: %{
          unprocessable_entity: %Response{
            description: "Unprocessable Entity",
            content: %{"application/json" => %MediaType{schema: %Schema{type: :object}}}
          },
          not_found: %Response{
            description: "Not Found",
            content: %{"application/json" => %MediaType{schema: %Schema{type: :string}}}
          },
          bad_request: %Response{description: "Bad Request"},
          no_content: %Response{description: "No Content"},
          forbidden: %Response{description: "Forbidden"}
        }
      },
      security: [%{"authorization" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp version, do: @app |> Application.spec(:vsn) |> to_string()

  defp name, do: @app |> Application.spec(:description) |> to_string()
end
