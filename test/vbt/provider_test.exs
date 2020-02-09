defmodule VBT.ProviderTest do
  use ExUnit.Case, async: true
  import VBT.TestHelper
  alias VBT.Provider

  describe "fetch_one" do
    test "returns correct value" do
      param = param_spec()
      System.put_env(param.os_env_name, "some value")
      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, "some value"}
    end

    test "returns default value if OS env is not set" do
      param = param_spec(default: "default value")

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) ==
               {:ok, "default value"}
    end

    test "ignores default value and returns OS env value if it's available" do
      param = param_spec(default: "default value")
      System.put_env(param.os_env_name, "os env value")

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) ==
               {:ok, "os env value"}
    end

    test "converts to integer" do
      param = param_spec(type: :integer, default: 123)

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, 123}

      System.put_env(param.os_env_name, "456")
      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, 456}
    end

    test "converts to float" do
      param = param_spec(type: :float, default: 3.14)

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, 3.14}

      System.put_env(param.os_env_name, "2.72")
      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, 2.72}
    end

    test "converts to boolean" do
      param = param_spec(type: :boolean, default: true)

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, true}

      System.put_env(param.os_env_name, "false")
      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) == {:ok, false}
    end

    test "reports error on missing value" do
      param = param_spec()

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) ==
               {:error, [error(param, "is missing")]}
    end

    test "empty string is treated as a missing value" do
      param = param_spec()
      System.put_env(param.os_env_name, "")

      assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) ==
               {:error, [error(param, "is missing")]}
    end

    for type <- ~w/integer float boolean/a do
      test "reports error on #{type} conversion" do
        param = param_spec(type: unquote(type), default: 123)
        System.put_env(param.os_env_name, "invalid value")

        assert Provider.fetch_one(Provider.SystemEnv, param.name, param.opts) ==
                 {:error, [error(param, "is invalid")]}
      end
    end
  end

  describe "fetch_one!" do
    test "returns correct value" do
      param = param_spec()
      System.put_env(param.os_env_name, "some value")
      assert Provider.fetch_one!(Provider.SystemEnv, param.name, param.opts) == "some value"
    end

    test "returns default value if OS env is not set" do
      param = param_spec()

      assert_raise(
        RuntimeError,
        "#{param.os_env_name} is missing",
        fn -> Provider.fetch_one!(Provider.SystemEnv, param.name, param.opts) end
      )
    end
  end

  describe "fetch_all" do
    test "returns correct values" do
      param1 = param_spec()
      param2 = param_spec(type: :integer)
      param3 = param_spec(type: :float, default: 3.14)

      System.put_env(param1.os_env_name, "some value")
      System.put_env(param2.os_env_name, "42")

      params = Enum.into([param1, param2, param3], %{}, &{&1.name, &1.opts})

      assert Provider.fetch_all(Provider.SystemEnv, params) ==
               {:ok, %{param1.name => "some value", param2.name => 42, param3.name => 3.14}}
    end

    test "reports errors" do
      param1 = param_spec()
      param2 = param_spec(type: :integer, default: 42)
      param3 = param_spec(type: :float)

      System.put_env(param3.os_env_name, "invalid value")

      params = Enum.into([param1, param2, param3], %{}, &{&1.name, &1.opts})

      assert Provider.fetch_all(Provider.SystemEnv, params) ==
               {:error, Enum.sort([error(param1, "is missing"), error(param3, "is invalid")])}
    end
  end

  defp param_spec(overrides \\ []) do
    name = :"test_env_#{unique_positive_integer()}"
    opts = Map.merge(%{type: :string, default: nil}, Map.new(overrides))
    os_env_name = name |> to_string() |> String.upcase()
    %{name: name, opts: opts, os_env_name: os_env_name}
  end

  defp error(param, message), do: "#{param.os_env_name} #{message}"
end
