defmodule VBT do
  @moduledoc "Common helper functions"

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Converts a boolean into `:ok | {:error, reason}`."
  @spec validate(boolean, error) :: :ok | {:error, error} when error: var
  def validate(condition, error), do: if(condition, do: :ok, else: {:error, error})

  @doc "Converts a boolean into `:ok | {:error, :unauthorized}`."
  @spec authorize(boolean) :: :ok | {:error, :unauthorized}
  def authorize(condition), do: validate(condition, :unauthorized)
end
