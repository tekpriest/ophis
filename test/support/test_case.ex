defmodule Ophis.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Persistence.DataCase,
        otp_app: :ophis,
        repo: Ophis.Repo
    end
  end
end
