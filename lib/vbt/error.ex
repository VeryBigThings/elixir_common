defmodule VBT.Error do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      defstruct [__vbt_error__: true] ++ Keyword.fetch!(opts, :fields)
      @type t :: %__MODULE__{}
    end
  end
end

defmodule VBT.BusinessError do
  @moduledoc "General purpose VBT business error."
  use VBT.Error, fields: [:error_code]

  @doc """
  Creates a VBT business error.

  The `scope` parameter can consist of multiple parts separated by the `.` character. At the
  very least supply a single part which is the operation name, or a standard VBT scope (e.g.
  `"registration"` or `"authentication"`).

  The prefix `com.vbt.` will be prepended to the given scope.

  The `reason` parameter represents the specific error reason (e.g. `"already_taken"`, or
  `"invalid_credentials"`).

  Example:

      iex> error = VBT.BusinessError.new("registration.login", "already_taken")

      iex> error.error_code
      "com.vbt.registration.login/already_taken"
  """
  @spec new(String.t(), String.t()) :: t
  def new(scope, reason), do: %__MODULE__{error_code: "com.vbt.#{scope}/#{reason}"}
end
