defmodule Ophis.Web.FallbackController do
  @moduledoc false

  alias Ophis.Web

  use Web, :controller

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(422)
    |> put_view(Web.ErrorView)
    |> render("error_response.json", message: message)
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(401)
    |> put_view(Web.ErrorView)
    |> render("error_response.json", message: "Unauthorized")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(400)
    |> put_view(Web.ErrorView)
    |> render("error_response.json", message: "Bad Request")
  end

  def call(conn, :error) do
    conn
    |> put_status(400)
    |> put_view(Web.ErrorView)
    |> render("error_response.json", message: "Bad Request")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(404)
    |> put_view(Web.ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, errors}) when is_list(errors) do
    conn
    |> put_status(422)
    |> put_view(Web.ErrorView)
    |> json(%{message: "Unprocessable Entity", errors: Enum.into(errors, %{})})
  end

  def call(conn, {:error, errors}) when is_map(errors) do
    conn
    |> put_status(422)
    |> put_view(Web.ErrorView)
    |> json(%{message: "Unprocessable Entity", errors: errors})
  end

  def call(conn, {:error, message}) do
    conn
    |> put_status(400)
    |> put_view(Web.ErrorView)
    |> render("error_response.json", message: message)
  end
end
