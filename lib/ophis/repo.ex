defmodule Ophis.Repo do
  @moduledoc false

  use Persistence.RepoTemplate,
    otp_app: :ophis,
    adapter: Ecto.Adapters.Postgres
end
