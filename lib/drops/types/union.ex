defmodule Qol.Drops.Types.Union do
  @moduledoc ~S"""
  Qol.Drops.Types.Union is a struct that represents a union type with left and right types.

  ## Examples

      iex> Qol.Drops.Type.Compiler.visit([{:type, {:string, []}}, {:type, {:integer, []}}], [])
      %Qol.Drops.Types.Union{
        left: %Qol.Drops.Types.Primitive{
          primitive: :string,
          constraints: [predicate: {:type?, :string}]
        },
        right: %Qol.Drops.Types.Primitive{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        },
        opts: []
      }

  """

  defmodule Validator do
    def validate(
          %{left: %{primitive: _} = left, right: %{primitive: _} = right} = type,
          input
        ) do
      case Qol.Drops.Type.Validator.validate(left, input) do
        {:ok, value} ->
          {:ok, value}

        {:error, meta} = left_error ->
          if is_list(meta) and meta[:predicate] != :type? do
            left_error
          else
            case Qol.Drops.Type.Validator.validate(right, input) do
              {:ok, value} ->
                {:ok, value}

              {:error, _} = right_error ->
                {:error, {:or, {left_error, right_error, type.opts}}}
            end
          end
      end
    end

    def validate(%{left: left, right: right} = type, input) do
      case Qol.Drops.Type.Validator.validate(left, input) do
        {:ok, value} ->
          {:ok, value}

        {:error, _} = left_error ->
          case Qol.Drops.Type.Validator.validate(right, input) do
            {:ok, value} ->
              {:ok, value}

            {:error, _} = right_error ->
              {:error, {:or, {left_error, right_error, type.opts}}}
          end
      end
    end
  end

  defmacro __using__(spec) do
    quote do
      use Qol.Drops.Type do
        deftype([:left, :right])

        import Qol.Drops.Types.Union

        @type_spec unquote(spec)

        @before_compile Qol.Drops.Types.Union

        defimpl Qol.Drops.Type.Validator, for: __MODULE__ do
          def validate(type, data), do: Validator.validate(type, data)
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Qol.Drops.Type.Compiler

      def new(predicates, opts) do
        type = new(Keyword.merge(@opts, opts))

        Map.merge(type, %{
          left: constrain(type.left, predicates),
          right: constrain(type.right, predicates)
        })
      end

      def new(opts) do
        {:union, {left, right}} = @type_spec

        struct(__MODULE__, %{
          left: Compiler.visit(left, opts),
          right: Compiler.visit(right, opts),
          opts: Keyword.merge(@opts, opts)
        })
      end

      defp constrain(type, predicates) do
        Map.merge(type, %{
          constraints: type.constraints ++ infer_constraints(predicates)
        })
      end
    end
  end

  use Qol.Drops.Type do
    deftype([:left, :right])

    def new(left, right) when is_struct(left) and is_struct(right) do
      struct(__MODULE__, left: left, right: right)
    end
  end

  defimpl Qol.Drops.Type.Validator, for: Union do
    def validate(type, input), do: Validator.validate(type, input)
  end
end
