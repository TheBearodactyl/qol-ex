## All credits for this part of the library go to ImNotAVirus on GitHub

defmodule StdResult do
  @moduledoc ~S"""
  `StdResult` provides a way to standardize the return types of Elixir functions.

  To help with pattern matching, the API also provides 3 macros:

  - `ok!/1`: same as `ok/1` but can be used in guards, pattern matching, ...
  - `err!/1`: same as `err/1` but can be used in guards, pattern matching, ...
  - `unit!/0`: same as `unit/0` but can be used in guards, pattern matching, ...

  ## Note

  In this library, we will use the term `Ok` for `:ok tuple` / `:ok Result` and
  `Err` for `:error tuple` / `:error Result`.

  ## Examples

      iex> import StdResult
      iex> System.fetch_env("PORT")
      ...> |> normalize_result() # This will transform `:error` into a `:error` tuple
      ...> |> or_result(err("PORT env required")) # If there is an error, explicit the message
      ...> |> map(&String.to_integer/1) # If no error, parse the string as an integer
      ...> |> and_then(&(if &1 >= 0, do: ok(&1), else: err("PORT must be a positive number, got: #{&1}"))) # Test if number is positive

      # The result will be either:
      # - `{:ok, port}`
      # - `{:error, "PORT env required"}`
      # - `{:error, "PORT must be a positive number, got: <value>"}`

  """

  @type ok :: {:ok, any()}
  @type ok(t) :: {:ok, t}
  @type err :: {:error, any()}
  @type err(e) :: {:error, e}
  @type result :: ok() | err()
  @type result(t, e) :: ok(t) | err(e)

  ## Public API - Macros

  @doc "Same as `ok/1` but can be used in guards, pattern matching, ..."
  defmacro ok!(term), do: {:ok, term}

  @doc "Same as `err/1` but can be used in guards, pattern matching, ..."
  defmacro err!(term), do: {:error, term}

  @doc "Same as `unit/0` but can be used in guards, pattern matching, ..."
  defmacro unit!(), do: Macro.escape({})

  ## Public API - Functions

  @doc ~S"""
  Wrap the input inside a tuple if needed.

  NOTE: This function does not try to guess the type of Result and needs
  to receive an atom `:ok` or `:error`. If you want to wrap any term, you
  can use `ok/1` or `err/1`.

  It is mainly used to manipulate, normalize and chain Elixir functions
  such as `System.fetch_env/1` or `System.delete_env/1` which return
  `:ok` or `:error` without tuple.

  ## Examples

      iex> StdResult.normalize_result(:ok)
      {:ok, {}}

      iex> StdResult.normalize_result(:error)
      {:error, {}}

      iex> StdResult.normalize_result({:ok, :foo})
      {:ok, :foo}

      iex> StdResult.normalize_result({:error, :bar})
      {:error, :bar}

  """
  @spec normalize_result(u) :: result() when u: :ok | :error | result()
  def normalize_result(:ok), do: ok!(unit!())
  def normalize_result(:error), do: err!(unit!())
  def normalize_result(ok!(_term) = ok), do: ok
  def normalize_result(err!(_term) = error), do: error

  @doc ~S"""
  Wrap any term inside a `:ok` tuple.

  ## Examples

      iex> StdResult.ok("value")
      {:ok, "value"}

  """
  @spec ok(t) :: ok(t) when t: any()
  def ok(term), do: ok!(term)

  @doc ~S"""
  Wrap any term inside a `:error` tuple.

  ## Examples

      iex> StdResult.err("unexpected error")
      {:error, "unexpected error"}

  """
  @spec err(e) :: err(e) when e: any()
  def err(term), do: err!(term)

  @doc ~S"""
  The `{}` type, also called "unit".

  The `{}` type has exactly one value `{}`, and is used when there is no
  other meaningful value that could be returned.

  ## Examples

      iex> StdResult.unit()
      {}

  """
  @spec unit() :: {}
  def unit(), do: unit!()

  @doc ~S"""
  Returns `true` if the result is `Ok`.

  ## Examples

      iex> StdResult.ok?({:ok, -3})
      true

      iex> StdResult.ok?({:error, "Some error message"})
      false

  """
  @spec ok?(result()) :: boolean()
  def ok?(ok!(_term)), do: true
  def ok?(err!(_reason)), do: false

  @doc ~S"""
  Returns `true` if the result is `Ok` and the value inside of
  it matches a predicate.

  ## Examples

      iex> StdResult.ok_and?({:ok, 2}, &(&1 > 1))
      true

      iex> StdResult.ok_and?({:ok, 0}, &(&1 > 1))
      false

      iex> StdResult.ok_and?({:error, "hey"}, &(&1 > 1))
      false

  """
  @spec ok_and?(result(t, e), (t -> boolean())) :: boolean()
        when t: any(), e: any()
  def ok_and?(ok!(term), fun), do: fun.(term)
  def ok_and?(err!(_reason), _fun), do: false

  @doc ~S"""
  Returns `true` if the result is `Err`.

  ## Examples

      iex> StdResult.err?({:ok, -3})
      false

      iex> StdResult.err?({:error, "Some error message"})
      true

  """
  @spec err?(result()) :: boolean()
  def err?(ok!(_term)), do: false
  def err?(err!(_reason)), do: true

  @doc ~S"""
  Returns `true` if the result is `Err` and the value inside of it matches
  a predicate.

  ## Examples

      iex> StdResult.err_and?({:error, :not_found}, &(&1 == :not_found))
      true

      iex> StdResult.err_and?({:error, :failed}, &(&1 == :not_found))
      false

      iex> StdResult.err_and?({:ok, 123}, &(&1 == :not_found))
      false

  """
  @spec err_and?(result(t, e), (e -> boolean())) :: boolean()
        when t: any(), e: any()
  def err_and?(ok!(_term), _fun), do: false
  def err_and?(err!(reason), fun), do: fun.(reason)

  @doc ~S"""
  Maps a Result into another by applying a function to a contained `Ok`
  value, leaving an `Err` value untouched.

  This function can be used to compose the results of two functions.

  ## Examples

      iex> StdResult.map({:ok, "123"}, &String.to_integer/1)
      {:ok, 123}

      iex> StdResult.map({:error, :not_found}, &String.to_integer/1)
      {:error, :not_found}

  """
  @spec map(result(t, e), (t -> u)) :: result(u, e)
        when t: any(), e: any(), u: any()
  def map(ok!(term), fun), do: term |> fun.() |> ok!()
  def map(err!(_reason) = error, _fun), do: error

  @doc ~S"""
  Returns the provided default (if `Err`), or applies a function to the
  contained value (if `Ok`).

  Arguments passed to `map_or/3` are eagerly evaluated; if you are passing
  the result of a function call, it is recommended to use `map_or_else/3`,
  which is lazily evaluated.

  ## Examples

      iex> StdResult.map_or({:ok, "foo"}, 42, &String.length/1)
      3

      iex> StdResult.map_or({:error, "bar"}, 42, &String.length/1)
      42

  """
  @spec map_or(result(t, e), u, (t -> u)) :: u
        when t: any(), e: any(), u: any()
  def map_or(ok!(term), _default, fun), do: fun.(term)
  def map_or(err!(_reason), default, _fun), do: default

  @doc ~S"""
  Maps a Result to a value by applying fallback function `default` to a
  contained `Err` value, or function `fun` to a contained `Ok` value.

  This function can be used to unpack a successful result while handling an
  error.

  ## Examples

      iex> StdResult.map_or_else({:ok, "foo"}, &(&1), &String.length/1)
      3

      iex> StdResult.map_or_else({:error, "bar"}, &(&1), &String.length/1)
      "bar"

  """
  @spec map_or_else(result(t, e), (e -> u), (t -> u)) :: u
        when t: any(), e: any(), u: any()
  def map_or_else(ok!(term), _default, fun), do: fun.(term)
  def map_or_else(err!(reason), default, _fun), do: default.(reason)

  @doc ~S"""
  Maps a Result into another by applying a function to a contained `Err`
  value, leaving an `Ok` value untouched.

  This function can be used to pass through a successful result while
  handling an error.

  ## Examples

      iex> StdResult.map_err({:ok, 2}, &"error code: #{&1}")
      {:ok, 2}

      iex> StdResult.map_err({:error, 13}, &"error code: #{&1}")
      {:error, "error code: 13"}

  """
  @spec map_err(result(t, e), (e -> f)) :: result(t, f)
        when t: any(), e: any(), f: any()
  def map_err(ok!(_term) = ok, _fun), do: ok
  def map_err(err!(reason), fun), do: reason |> fun.() |> err!()

  @doc ~S"""
  Calls the provided closure with a reference to the contained value (if `Ok`).

  ## Examples

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> StdResult.inspect({:ok, 21}, &IO.inspect/1) end)
      "21\n"

      iex> StdResult.inspect({:ok, 21}, &Function.identity/1)
      {:ok, 21}

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> StdResult.inspect({:error, 42}, &IO.inspect/1) end)
      ""

      iex> StdResult.inspect({:error, 42}, &Function.identity/1)
      {:error, 42}

  """
  @spec inspect(result(t, e), (t -> any())) :: result(t, e)
        when t: any(), e: any()
  def inspect(result, fun) do
    case result do
      ok!(term) -> fun.(term)
      _ -> :ok
    end

    result
  end

  @doc ~S"""
  Calls the provided closure with a reference to the contained value (if `Err`).

  ## Examples

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> StdResult.inspect_err({:ok, 21}, &IO.inspect/1) end)
      ""

      iex> StdResult.inspect_err({:ok, 21}, &Function.identity/1)
      {:ok, 21}

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> StdResult.inspect_err({:error, 42}, &IO.inspect/1) end)
      "42\n"

      iex> StdResult.inspect_err({:error, 42}, &Function.identity/1)
      {:error, 42}

  """
  @spec inspect_err(result(t, e), (e -> any())) :: result(t, e)
        when t: any(), e: any()
  def inspect_err(result, fun) do
    case result do
      err!(reason) -> fun.(reason)
      _ -> :ok
    end

    result
  end

  @doc ~S"""
  Returns the contained `Ok` value.

  Because this function may raise, its use is generally discouraged.
  Instead, prefer to use pattern matching and handle the `Err` case
  explicitly, or call `unwrap_or/2` or `unwrap_or_else/2`.

  ## Examples

      iex> StdResult.expect({:ok, 21}, "Testing expect")
      21

      iex> StdResult.expect({:error, "emergency failure"}, "Testing expect")
      ** (RuntimeError) Testing expect: emergency failure

  ## Recommended Message Style

  We recommend that `expect/2` messages are used to describe the reason you
  expect the Result should be `Ok`.

      iex> System.fetch_env("IMPORTANT_PATH")
      ...> |> StdResult.normalize_result()
      ...> |> StdResult.expect("env variable `IMPORTANT_PATH` should be set by `wrapper_script.sh`")
      ** (RuntimeError) env variable `IMPORTANT_PATH` should be set by `wrapper_script.sh`: {}

  **Hint**: If you’re having trouble remembering how to phrase expect error
  messages remember to focus on the word “should” as in “env variable should
  be set by blah” or “the given binary should be available and executable
  by the current user”.

  """
  @spec expect(result(t, e), String.t()) :: t | no_return()
        when t: any(), e: any()
  def expect(ok!(term), _label), do: term
  def expect(err!(reason), label) when is_binary(reason), do: raise("#{label}: #{reason}")
  def expect(err!(reason), label), do: raise("#{label}: #{inspect(reason)}")

  @doc ~S"""
  Returns the contained `Ok` value.

  Because this function may raise, its use is generally discouraged.
  Instead, prefer to use pattern matching and handle the `Err` case
  explicitly, or call `unwrap_or/2` or `unwrap_or_else/2`.

  ## Examples

      iex> StdResult.unwrap({:ok, 21})
      21

      iex> StdResult.unwrap({:error, "emergency failure"})
      ** (RuntimeError) emergency failure

  """
  @spec unwrap(result(t, e)) :: t | no_return()
        when t: any(), e: any()
  def unwrap(ok!(term)), do: term
  def unwrap(err!(reason)) when is_binary(reason), do: raise(reason)
  def unwrap(err!(reason)), do: raise(inspect(reason))

  @doc ~S"""
  Returns the contained `Err` value.

  For more details, see: `expect/2`

  ## Examples

      iex> StdResult.expect_err({:error, "emergency failure"}, "Testing expect")
      "emergency failure"

      iex> StdResult.expect_err({:ok, 42}, "Testing expect")
      ** (RuntimeError) Testing expect: 42

  """
  @spec expect_err(result(t, e), String.t()) :: e | no_return()
        when t: any(), e: any()
  def expect_err(ok!(reason), label) when is_binary(reason), do: raise("#{label}: #{reason}")
  def expect_err(ok!(reason), label), do: raise("#{label}: #{inspect(reason)}")
  def expect_err(err!(term), _label), do: term

  @doc ~S"""
  Returns the contained `Err` value.

  For more details, see: `unwrap/1`

  ## Examples

      iex> StdResult.unwrap_err({:error, "emergency failure"})
      "emergency failure"

      iex> StdResult.unwrap_err({:ok, 42})
      ** (RuntimeError) 42

  """
  @spec unwrap_err(result(t, e)) :: e | no_return()
        when t: any(), e: any()
  def unwrap_err(ok!(reason)) when is_binary(reason), do: raise(reason)
  def unwrap_err(ok!(reason)), do: raise(inspect(reason))
  def unwrap_err(err!(term)), do: term

  @doc ~S"""
  Returns the right operand if the result is `Ok`, otherwise returns the
  `Err` value.

  Arguments passed to `and_result/2` are eagerly evaluated; if you are
  passing the result of a function call, it is recommended to use
  `and_then/2`, which is lazily evaluated.

  ## Examples

      iex> StdResult.and_result({:ok, 2}, {:error, "late error"})
      {:error, "late error"}

      iex> StdResult.and_result({:error, "early error"}, {:error, "foo"})
      {:error, "early error"}

      iex> StdResult.and_result({:error, "not a 2"}, {:error, "late error"})
      {:error, "not a 2"}

      iex> StdResult.and_result({:ok, 2}, {:ok, "different result type"})
      {:ok, "different result type"}

  """
  @spec and_result(result(t, e), result(u, e)) :: result(u, e)
        when t: any(), e: any(), u: any()
  def and_result(ok!(_term), result), do: result
  def and_result(err!(_reason) = error, _result), do: error

  @doc ~S"""
  Calls the callback if the result is `Ok`, otherwise returns the `Err` value.

  This function can be used for control flow based on Result values.

  ## Examples

      iex> StdResult.and_then({:ok, 2}, &{:ok, &1 * 2})
      {:ok, 4}

      iex> StdResult.and_then({:ok, 1_000_000}, fn _ -> {:error, "overflowed"} end)
      {:error, "overflowed"}

      iex> StdResult.and_then({:error, "not a number"}, &(&1 * 2))
      {:error, "not a number"}

  """
  @spec and_then(result(t, e), (t -> result(u, e))) :: result(u, e)
        when t: any(), e: any(), u: any()
  def and_then(ok!(term), fun), do: fun.(term)
  def and_then(err!(_reason) = error, _fun), do: error

  @doc ~S"""
  Returns the right operand if the result is `Err`, otherwise returns the
  `Ok` value.

  Arguments passed to `or_result/2` are eagerly evaluated; if you are
  passing the result of a function call, it is recommended to use
  `or_else/2`, which is lazily evaluated.

  ## Examples

      iex> StdResult.or_result({:ok, 2}, {:error, "late error"})
      {:ok, 2}

      iex> StdResult.or_result({:error, "early error"}, {:ok, 2})
      {:ok, 2}

      iex> StdResult.or_result({:error, "not a 2"}, {:error, "late error"})
      {:error, "late error"}

      iex> StdResult.or_result({:ok, 2}, {:ok, 100})
      {:ok, 2}

  """
  @spec or_result(result(t, e), result(t, f)) :: result(t, f)
        when t: any(), e: any(), f: any()
  def or_result(ok!(_term) = ok, _result), do: ok
  def or_result(err!(_reason), result), do: result

  @doc ~S"""
  Calls the callback if the result is `Err`, otherwise returns the `Ok` value.

  This function can be used for control flow based on Result values.

  ## Examples

      iex> StdResult.or_else({:ok, 2}, &{:ok, &1 * 2})
      {:ok, 2}

      iex> StdResult.or_else({:ok, 2}, &{:error, &1 * 4})
      {:ok, 2}

      iex> StdResult.or_else({:error, 2}, &{:ok, &1 * 2})
      {:ok, 4}

      iex> StdResult.or_else({:error, 2}, &{:error, &1 * 4})
      {:error, 8}

  """
  @spec or_else(result(t, e), (e -> result(t, f))) :: result(t, f)
        when t: any(), e: any(), f: any()
  def or_else(ok!(_term) = ok, _fun), do: ok
  def or_else(err!(reason), fun), do: fun.(reason)

  @doc ~S"""
  Returns the contained `Ok` value or a provided default.

  Arguments passed to `unwrap_or/2` are eagerly evaluated; if you are
  passing the result of a function call, it is recommended to use
  `unwrap_or_else/2`, which is lazily evaluated.

  ## Examples

      iex> StdResult.unwrap_or({:ok, 2}, 42)
      2

      iex> StdResult.unwrap_or({:error, "error"}, 42)
      42

  """
  @spec unwrap_or(result(t, e), t) :: t
        when t: any(), e: any()
  def unwrap_or(ok!(term), _default), do: term
  def unwrap_or(err!(_reason), default), do: default

  @doc ~S"""
  Returns the contained `Ok` value or computes it from a closure.

  ## Examples

      iex> StdResult.unwrap_or_else({:ok, 2}, &String.length/1)
      2

      iex> StdResult.unwrap_or_else({:error, "foo"}, &String.length/1)
      3

  """
  @spec unwrap_or_else(result(t, e), (e -> t)) :: t
        when t: any(), e: any()
  def unwrap_or_else(ok!(term), _fun), do: term
  def unwrap_or_else(err!(reason), fun), do: fun.(reason)

  @doc ~S"""
  Partition a sequence of Results into one list of all the `Ok` elements
  and another list of all the `Err` elements.

  ## Examples

      iex> ok_and_errors = [{:ok, 1}, {:error, false}, {:error, true}, {:ok, 2}]
      iex> StdResult.partition_result(ok_and_errors)
      {[1, 2], [false, true]}

  """
  @spec partition_result([result(t, e)]) :: {[t], [e]}
        when t: any(), e: any()
  def partition_result(results) do
    {oks, errors} =
      Enum.reduce(results, {[], []}, fn
        ok!(ok), {os, es} -> {[ok | os], es}
        err!(err), {os, es} -> {os, [err | es]}
      end)

    {Enum.reverse(oks), Enum.reverse(errors)}
  end
end
