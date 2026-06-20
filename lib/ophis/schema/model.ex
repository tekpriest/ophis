defmodule Ophis.Schema.Model do
  @moduledoc false

  use Persistence.Schema, prefix: "ophis"

  schema "models" do
    field(:sample_field, :string)
    field(:data, :map)

    timestamps(type: :utc_datetime)
  end
end
