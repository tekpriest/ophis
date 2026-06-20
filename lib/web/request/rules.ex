defmodule Ophis.Web.Request.Rules do
  @moduledoc false

  use Request.Validator.Rules

  alias CommonUtils.StringUtils
  alias CommonUtils.Validation.{Currency, Id}

  @type validation_result :: :ok | {:error, binary()}

  @spec currency(T.currency(), keyword()) :: validation_result()
  def currency(currency, _opts) when is_binary(currency) do
    currency |> StringUtils.to_atom() |> Currency.validate_currency()
  end

  def currency(_c, _opts), do: {:error, "is not a string"}

  @spec id(binary(), keyword()) :: validation_result()
  def id(id, _opts) when is_binary(id), do: Id.validate_id(id)
  def id(_c, _opts), do: {:error, "not a string"}
end
