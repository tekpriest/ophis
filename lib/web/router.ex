defmodule Ophis.Web.Router do
  @moduledoc false

  alias Ophis.Web

  use Web, :router

  @swagger_config [path: "/ophis/apidoc.json", default_model_expand_depth: 3, display_operation_id: true]

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self' 'unsafe-inline'"}
    plug RequestResponseLogger
    plug Plug.Telemetry, event_prefix: [:ophis, :plug]
  end

  # pipeline :auth do
  #   plug Auth.Plug.AuthPipeline
  #   plug Auth.Plug.EnsureAccountIsLoaded
  # end

  pipeline :docs do
    plug :accepts, ["json", "html"]

    plug :put_secure_browser_headers, %{
      "content-security-policy" => "default-src 'self' 'unsafe-inline' cdnjs.cloudflare.com"
    }

    plug OpenApiSpex.Plug.PutApiSpec, module: Web.Spec
  end

  scope "/ophis" do
    pipe_through ~w[docs]a

    get "/apidoc.json", OpenApiSpex.Plug.RenderSpec, []
    get "/apidoc", OpenApiSpex.Plug.SwaggerUI, @swagger_config
  end

  scope "/" do
    pipe_through ~w[docs]a

    get "/apidoc.json", OpenApiSpex.Plug.RenderSpec, []
    get "/apidoc", OpenApiSpex.Plug.SwaggerUI, @swagger_config
  end

  scope "/ophis", Web do
    pipe_through :api

    post "/ingest", IngestController, :ingest
  end
end
