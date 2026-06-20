defmodule Ophis.TestUtils do
  @moduledoc false
  alias Ophis.Model
  alias Persistence.Storage.Common

  def flush do
    Common.flush([Model], Ophis.repository())
  end
end
