defmodule VBT.Graphql.ScalarsTest do
  use VBT.Graphql.Case, async: true, endpoint: VBT.GraphqlServer, api_path: "/"

  describe "datetime_usec" do
    test "decodes valid input" do
      assert {:ok, response} = datetime_usec("2020-01-02T01:02:03.456789Z")
      assert response.decoded == ~U[2020-01-02 01:02:03.456789Z]
    end

    test "encodes valid input" do
      assert {:ok, response} = datetime_usec("2020-01-02T01:02:03.456789Z")
      assert response.encoded == "2020-01-02T01:02:03.456789Z"
    end

    test "supports nil" do
      assert {:ok, response} = datetime_usec(nil)
      assert response.decoded == nil
      assert response.encoded == nil
    end

    test "returns error on invalid input" do
      assert {:error, %{errors: [error]}} = datetime_usec("invalid value")
      assert error.message =~ ~s/Argument "value" has invalid value/
    end

    test "normalizes to microseconds granularity while decoding" do
      {:ok, response} = datetime_usec("2020-01-02T01:02:03.456789Z")
      assert response.decoded.microsecond == {456_789, 6}

      {:ok, response} = datetime_usec("2020-01-02T01:02:03.456Z")
      assert response.decoded.microsecond == {456_000, 6}

      {:ok, response} = datetime_usec("2020-01-02T01:02:03Z")
      assert response.decoded.microsecond == {0, 6}
    end

    test "normalizes to microseconds granularity while encoding" do
      {:ok, response} = datetime_usec("2020-01-02T01:02:03.456789Z")
      assert response.encoded_msec == "2020-01-02T01:02:03.456000Z"
      assert response.encoded_sec == "2020-01-02T01:02:03.000000Z"
    end

    defp datetime_usec(value) do
      with {:ok, response} <-
             call(
               "query($value: String) {
                 datetime_usec(value: $value) {decoded encoded encoded_msec encoded_sec}
                }",
               variables: %{value: value}
             ) do
        {:ok,
         Map.update!(
           response.datetime_usec,
           :decoded,
           &(&1 |> Base.decode64!() |> :erlang.binary_to_term())
         )}
      end
    end
  end
end
