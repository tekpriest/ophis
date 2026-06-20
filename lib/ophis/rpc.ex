defmodule Ophis.Rpc do
  @moduledoc false

  @app :ophis
  use JuiceRpc,
    otp_app: @app,
    port_resolver: &__MODULE__.port_resolver/2,
    service_module: Ophis

  def client_options, do: [env: Application.get_env(@app, :env)]

  def port_resolver(_node, :accounts) do
    case Application.get_env(@app, :env) do
      :prod -> 5000
      _ -> 4510
    end
  end

  def port_resolver(_node, _), do: 5000

  def call_accounts(mod, fun, args), do: request(mod, fun, args, service: :accounts)
end
