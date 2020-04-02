defmodule VBT.Provider do
  @moduledoc deprecated: "Use https://github.com/verybigthings/provider instead"

  alias Ecto.Changeset

  @type source :: module
  @type params :: %{param_name => param_spec}
  @type param_name :: atom
  @type param_spec :: %{type: type, default: value}
  @type type :: :string | :integer | :float | :boolean
  @type value :: String.t() | number | boolean | nil
  @type data :: %{param_name => value}

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Retrieves all params according to the given specification."
  @spec fetch_all(source, params) :: {:ok, data} | {:error, [String.t()]}
  def fetch_all(source, params) do
    types = Enum.into(params, %{}, fn {name, spec} -> {name, spec.type} end)

    data =
      params
      |> Stream.zip(source.values(Map.keys(types)))
      |> Enum.into(%{}, fn {{param, opts}, provided_value} ->
        value = if is_nil(provided_value), do: opts.default, else: provided_value
        {param, value}
      end)

    {%{}, types}
    |> Changeset.cast(data, Map.keys(types))
    |> Changeset.validate_required(Map.keys(types), message: "is missing")
    |> case do
      %Changeset{valid?: true} = changeset -> {:ok, Changeset.apply_changes(changeset)}
      %Changeset{valid?: false} = changeset -> {:error, changeset_error(source, changeset)}
    end
  end

  @doc "Retrieves a single parameter."
  @spec fetch_one(source, param_name, param_spec) :: {:ok, value} | {:error, [String.t()]}
  def fetch_one(source, param_name, param_spec) do
    with {:ok, map} <- fetch_all(source, %{param_name => param_spec}),
         do: {:ok, Map.fetch!(map, param_name)}
  end

  @doc "Retrieves a single param, raising if the value is not available."
  @spec fetch_one!(source, param_name, param_spec) :: value
  def fetch_one!(source, param, param_spec) do
    case fetch_one(source, param, param_spec) do
      {:ok, value} -> value
      {:error, errors} -> raise Enum.join(errors, ", ")
    end
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp changeset_error(source, changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(
        opts,
        msg,
        fn {key, value}, acc -> String.replace(acc, "%{#{key}}", to_string(value)) end
      )
    end)
    |> Enum.flat_map(fn {key, errors} ->
      Enum.map(errors, &"#{source.display_name(key)} #{&1}")
    end)
    |> Enum.sort()
  end

  @doc false
  defmacro __using__(spec) do
    spec =
      update_in(
        spec[:params],
        fn params -> Enum.map(params, &normalize_param_spec(&1, Mix.env())) end
      )

    quote bind_quoted: [spec: spec] do
      # Generate typespec mapping for each param
      typespecs =
        Enum.map(
          Keyword.fetch!(spec, :params),
          fn {param_name, param_spec} ->
            type =
              case Keyword.fetch!(param_spec, :type) do
                :integer -> quote(do: integer())
                :float -> quote(do: float())
                :boolean -> quote(do: boolean())
                :string -> quote(do: String.t())
              end

            {param_name, type}
          end
        )

      # Convert each param's spec into a quoted map. This is done so we can inject the map
      # with constants direcly into the function definition. In other words, this ensures that
      # we converted the input keyword list into a map at compile time, not runtime.
      quoted_params =
        spec
        |> Keyword.fetch!(:params)
        |> Enum.map(fn {name, spec} -> {name, quote(do: %{unquote_splicing(spec)})} end)

      @doc "Retrieves all parameters."
      @spec fetch_all :: {:ok, %{unquote_splicing(typespecs)}} | {:error, [String.t()]}
      def fetch_all do
        VBT.Provider.fetch_all(
          unquote(Keyword.fetch!(spec, :source)),

          # quoted_params is itself a keyword list, so we need to convert it into a map
          %{unquote_splicing(quoted_params)}
        )
      end

      @doc "Validates all parameters, raising if some values are missing or invalid."
      @spec validate! :: :ok
      def validate! do
        with {:error, errors} <- fetch_all() do
          raise "Following OS env var errors were found:\n#{Enum.join(Enum.sort(errors), "\n")}"
        end

        :ok
      end

      # Generate getter for each param.
      Enum.each(
        quoted_params,
        fn {param_name, param_spec} ->
          @spec unquote(param_name)() :: unquote(Keyword.fetch!(typespecs, param_name))
          @doc "Returns the value of the `#{param_name}` param, raising on error."
          # bug in credo spec check
          # credo:disable-for-next-line Credo.Check.Readability.Specs
          def unquote(param_name)() do
            VBT.Provider.fetch_one!(
              unquote(Keyword.fetch!(spec, :source)),
              unquote(param_name),
              unquote(param_spec)
            )
          end
        end
      )

      @doc "Returns a template configuration file."
      @spec template :: String.t()
      def template do
        unquote(Keyword.fetch!(spec, :source)).template(%{unquote_splicing(quoted_params)})
      end
    end
  end

  defp normalize_param_spec(param_name, mix_env) when is_atom(param_name),
    do: normalize_param_spec({param_name, []}, mix_env)

  defp normalize_param_spec({param_name, param_spec}, mix_env) do
    default_keys =
      case mix_env do
        :test -> [:test, :dev, :default]
        :dev -> [:dev, :default]
        :prod -> [:default]
      end

    default_value =
      default_keys
      |> Stream.map(&Keyword.get(param_spec, &1))
      |> Enum.find(&(not is_nil(&1)))

      # We need to escape to make sure that default of e.g. `foo()` is correctly passed to
      # `__using__` quote block and properly resolved as a runtime function call.
      #
      # The `unquote: true` option ensures that default of `unquote(foo)` is resolved in the
      # context of the client module.
      |> Macro.escape(unquote: true)

    {param_name, [type: Keyword.get(param_spec, :type, :string), default: default_value]}
  end

  defmodule Source do
    @moduledoc false
    alias VBT.Provider

    @doc """
    Invoked to provide the values for the given parameters.

    This function should return all values in the requested orders. For each param which is not
    available, `nil` should be returned.
    """
    @callback values([Provider.param_name()]) :: [Provider.value()]

    @doc "Invoked to convert the param name to storage specific name."
    @callback display_name(Provider.param_name()) :: String.t()

    @doc "Invoked to create operator template."
    @callback template(Provider.params()) :: String.t()
  end
end
