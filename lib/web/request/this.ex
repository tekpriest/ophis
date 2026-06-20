defmodule Ophis.Web.Request.This do
  @moduledoc false
  alias Ophis.Web
  use Request.Validator, rules_module: Ophis.Web.Request.Rules

  @impl true
  def rules(_conn), do: []

  @impl true
  def authorize(_conn), do: true
end
