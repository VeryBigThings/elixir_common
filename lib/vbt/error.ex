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
end
