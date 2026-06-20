defmodule Ophis do
  @moduledoc false

  @app :ophis

  use Rop

  # Interface functions

  def repository, do: Application.get_env(@app, :repo)

  def deployment_env, do: Application.get_env(@app, :deployment_env)

  def greet, do: "Hello, world!"
end
