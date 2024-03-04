defmodule Qol.Drops.Types.Map do
  @moduledoc ~S"""
  Qol.Drops.Types.Map is a struct that represents a map type with optional constraints.

  ## Examples

      iex> Qol.Drops.Type.Compiler.visit({:type, {:map, []}}, [])
      %Qol.Drops.Types.Primitive{primitive: :map, constraints: [predicate: {:type?, :map}]}

      iex> Qol.Drops.Type.Compiler.visit(%{
      ...>   {:required, :name} => {:type, {:string, []}},
      ...>   {:optional, :age} => {:type, {:integer, []}}
      ...> }, [])
      %Qol.Drops.Types.Map{
        primitive: :map,
        constraints: [predicate: {:type?, :map}],
        keys: [
          %Qol.Drops.Types.Map.Key{
            path: [:age],
            presence: :optional,
            type: %Qol.Drops.Types.Primitive{
              primitive: :integer,
              constraints: [predicate: {:type?, :integer}]
            }
          },
          %Qol.Drops.Types.Map.Key{
            path: [:name],
            presence: :required,
            type: %Qol.Drops.Types.Primitive{
              primitive: :string,
              constraints: [predicate: {:type?, :string}]
            }
          }
        ],
        atomize: false
      }

  """

  alias __MODULE__
  alias Qol.Drops.Predicates
  alias Qol.Drops.Types.Map.Key

  defmodule Validator do
    def validate(%{atomize: true, keys: keys} = type, data) do
      case Predicates.Helpers.apply_predicates(Map.atomize(data, keys), type.constraints) do
        {:ok, result} ->
          results = Enum.map(type.keys, &Key.validate(&1, result)) |> List.flatten()
          errors = Enum.reject(results, &Predicates.Helpers.ok?/1)

          if Enum.empty?(errors),
            do: {:ok, {:map, results}},
            else: {:error, {:map, results}}

        result ->
          result
      end
    end

    def validate(type, data) do
      case Predicates.Helpers.apply_predicates(data, type.constraints) do
        {:ok, result} ->
          results = Enum.map(type.keys, &Key.validate(&1, result)) |> List.flatten()
          errors = Enum.reject(results, &Predicates.Helpers.ok?/1)

          if Enum.empty?(errors),
            do: {:ok, {:map, results}},
            else: {:error, {:map, results}}

        {:error, {value, meta}} ->
          {:error, Keyword.merge([input: value], meta)}

        {:error, errors} ->
          {:error, errors}
      end
    end
  end

  defmacro __using__(opts) do
    quote do
      use Qol.Drops.Type do
        deftype(:map, keys: unquote(opts[:keys]), atomize: false)

        import Qol.Drops.Types.Map

        def new(opts) do
          struct(__MODULE__, opts)
        end

        def new(predicates, opts) do
          type = new(opts)

          Elixir.Map.merge(
            type,
            %{constraints: type.constraints ++ Qol.Drops.Type.infer_constraints(predicates)}
          )
        end

        defimpl Qol.Drops.Type.Validator, for: __MODULE__ do
          def validate(type, data), do: Validator.validate(type, data)
        end
      end
    end
  end

  use Qol.Drops.Type do
    deftype(:map, keys: [], atomize: false)
  end

  defimpl Qol.Drops.Type.Validator, for: Map do
    def validate(type, data), do: Validator.validate(type, data)
  end

  def new(keys, opts) when is_list(keys) do
    atomize = opts[:atomize] || false
    struct(__MODULE__, keys: keys, atomize: atomize)
  end

  def atomize(data, keys, initial \\ %{}) do
    Enum.reduce(keys, initial, fn %{path: path} = key, acc ->
      stringified_key = Key.stringify(key)

      if Key.present?(data, stringified_key) do
        put_in(acc, path, get_in(data, stringified_key.path))
      else
        acc
      end
    end)
  end
end
