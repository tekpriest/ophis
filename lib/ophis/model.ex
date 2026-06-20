alias Ophis.Model
alias Ophis.Schema.Model, as: Schema

defmodule Model do
  @moduledoc false

  alias CommonUtils.Id
  alias Ophis.T
  alias Persistence.{ResolveSchema, Storage}

  use CommonUtils.Validation.Model
  use Storage, module: __MODULE__, query_module: Ophis.Query.Model, app: :ophis, support_delete?: true

  @behaviour ResolveSchema

  defstruct ~w[id sample_field]a

  @type t :: %__MODULE__{
          id: T.id(),
          sample_field: String.t()
        }

  @spec new(String.t(), keyword()) :: t() | {:error, keyword()}
  def new(sample_field, opts \\ []) do
    attrs = %{
      id: Keyword.get_lazy(opts, :id, fn -> Id.new_id(:v1) end),
      sample_field: sample_field
    }

    case validate(attrs) do
      :ok -> struct!(__MODULE__, attrs)
      errors -> {:error, errors}
    end
  end

  def resolve_schema(_ \\ nil), do: Schema

  defp validate(attrs) do
    []
    |> require(attrs, :id, &validate_id/1)
    |> require(attrs, :sample_field, &validate_string/1)
  end
end

defimpl Jason.Encoder, for: Model do
  def encode(order, opts) do
    order
    |> Map.from_struct()
    |> Jason.Encode.map(opts)
  end
end

defimpl Persistence.ToChangeset, for: Model do
  import Ecto.Changeset

  @fields ~w[id sample_field data]a

  def transform(model, nil) do
    %Schema{}
    |> to_changeset(model)
    |> Map.put(:action, :insert)
  end

  def transform(model, %{} = record) do
    record
    |> to_changeset(model)
    |> Map.put(:action, :update)
  end

  def transform(model, query_fun) do
    model
    |> query_fun.()
    |> case do
      {:error, :not_found} -> transform(model, nil)
      {:ok, record} -> transform(model, record)
    end
  end

  defp to_changeset(schema, %Model{id: id, sample_field: sample_field} = model) do
    data =
      model
      |> Map.from_struct()
      |> Map.drop(~w[id sample_field]a)

    data = %{
      data: data,
      id: id,
      sample_field: sample_field
    }

    schema
    |> cast(data, @fields)
    |> validate_required(@fields)
  end
end

defimpl Persistence.ToModel, for: Schema do
  alias CommonUtils.{DateUtils, Transform}

  def transform(%_{id: id, sample_field: sample_field, data: data} = schema) do
    opts =
      data
      |> Transform.convert_string_keys_to_atom()
      |> Keyword.new()
      |> Keyword.put(:created_at, DateUtils.to_naive(schema.inserted_at))
      |> Keyword.put(:updated_at, DateUtils.to_naive(schema.updated_at))
      |> Keyword.put(:id, id)

    Model.new(sample_field, opts)
  end
end
