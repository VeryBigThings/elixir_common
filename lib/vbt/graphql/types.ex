defmodule VBT.Graphql.Types do
  @moduledoc "Custom VBT GraphQL types."

  use Absinthe.Schema.Notation

  object :business_error do
    description "VBT business error"
    field :error_code, non_null(:string)
  end

  scalar :datetime_usec, name: "DateTimeUsec" do
    description """
    Date and time with microseconds precision.

    In JSON format, the value is a valid ISO8601 datetime string. On the server side, the parsed
    value will be converted to UTC if there is an offset. The precision is normalized to
    microseconds.

    When encoding, the precision will be padded to microseconds if needed, and the encoded value
    will always be in the UTC time zone.
    """

    serialize &DateTime.to_iso8601(&1 && to_usec_precision(&1))
    parse &parse_datetime_usec/1
  end

  defp parse_datetime_usec(%Absinthe.Blueprint.Input.String{value: value}) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, to_usec_precision(datetime)}
      {:error, _} -> :error
    end
  end

  defp parse_datetime_usec(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp parse_datetime_usec(_), do: :error

  defp to_usec_precision(%{microsecond: {_value, 6}} = time_or_datetime),
    do: time_or_datetime

  defp to_usec_precision(%{microsecond: {value, _precision}} = time_or_datetime),
    do: %{time_or_datetime | microsecond: {value, 6}}
end
