defmodule Ophis.Query.Model do
  @moduledoc false

  use Persistence.Query, module: Ophis.Model

  @spec preprocess(keyword()) :: Ecto.Query.t()
  def preprocess(opts) do
    opts
    |> Enum.reduce([], fn
      {:data_field, x}, acc -> [{:detail, {&by_data_field/2, x}} | acc]
      {k, v}, acc -> [{k, v} | acc]
    end)
  end

  defp by_data_field(query, x), do: where(query, [x], x.data["data_field"] == ^x)
end
