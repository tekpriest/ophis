defmodule Ophis.Web do
  @moduledoc """
  The entrypoint for the web interface, such as controllers, views, channels and so on.
  This can be used in your application as:
      use Ophis.Web, :controller
      use Ophis.Web, :view
  """
  alias Ophis.Web

  def static_paths, do: ~w(css fonts images js favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller, namespace: Web

      import Plug.Conn
      use Gettext, backend: Web.Gettext
      alias Web.Router.Helpers, as: Routes
      action_fallback(Web.FallbackController)
      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/web/templates",
        namespace: Web

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: Web.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import Web.ErrorHelpers
      use Gettext, backend: Web.Gettext
      alias Web.Router.Helpers, as: Routes
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Web.Endpoint,
        router: Web.Router,
        statics: Web.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(Web, which, [])
  end
end
