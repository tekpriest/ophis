defmodule Ophis.Web.Controller do
  @moduledoc false
  alias Ophis.Web
  alias OpenApiSpex.Reference
  alias Web.Request.{That, This}

  use Web, :controller
  use OpenApiSpex.ControllerSpecs

  tags ["ophis"]

  plug Request.Validator.Plug,
    this: This,
    that: That


  operation :this,
    summary: "This",
    responses: [
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"}
    ]

  def this(_conn, _params) do
    {:error, "Not implemented"}
  end

  operation :that,
    summary: "That",
    responses: [
      not_found: %Reference{"$ref": "#/components/responses/not_found"}
    ]

  def that(_conn, _params) do
    {:error, :not_found}
  end
end
