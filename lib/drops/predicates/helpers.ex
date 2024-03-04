defmodule Qol.Drops.Predicates.Helpers do
  @moduledoc false

  alias Drops.Predicates

  def apply_predicates(value, {:and, predicates}) do
    apply_predicates(value, predicates)
  end

  def apply_predicates(value, predicates) do
    Enum.reduce(predicates, {:ok, value}, &apply_predicate(&1, &2))
  end

  def apply_predicate({:predicate, {name, args}}, {:ok, value}) do
    apply_args =
      case args do
        [arg] -> [arg, value]
        [] -> [value]
        arg -> [arg, value]
      end

    if apply(Predicates, name, apply_args) do
      {:ok, value}
    else
      {:error, [input: value, predicate: name, args: apply_args]}
    end
  end

  def apply_predicate(_, {:error, _} = error) do
    error
  end

  def ok?(results) when is_list(results), do: Enum.all?(results, &ok?/1)
  def ok?(:ok), do: true
  def ok?({:ok, _}), do: true
  def ok?(:error), do: false
  def ok?({:error, _}), do: false
end
