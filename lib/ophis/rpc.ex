defmodule Ophis.Rpc do
  @moduledoc false

  @app :ophis
  use JuiceRpc,
    otp_app: @app,
    service_module: Ophis

  def client_options, do: [env: Application.get_env(@app, :env)]

  def call_accounts(mod, fun, args), do: request(mod, fun, args, service: :accounts)
end
