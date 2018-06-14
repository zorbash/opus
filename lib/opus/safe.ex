defmodule Opus.Safe do
  @moduledoc false

  import Kernel, except: [apply: 2, apply: 3]

  def apply(term), do: apply(term, %{})

  def apply({_m, nil, _a}, _), do: nil

  def apply({m, f, a}, opts) do
    Kernel.apply(m, f, a)
  rescue
    e -> handle_exception(e, opts)
  end

  def apply(fun, opts) when is_function(fun, 0) do
    fun.()
  rescue
    e -> handle_exception(e, opts)
  end

  def apply(fun, arg) when is_function(fun, 1), do: apply(fun, arg, %{})

  def apply(fun, arg, opts \\ %{}) when is_function(fun, 1) do
    fun.(arg)
  rescue
    e -> handle_exception(e, opts)
  end

  defp handle_exception(e, %{raise: true}) do
    stacktrace = System.stacktrace()
    reraise e, stacktrace
  end

  defp handle_exception(e, %{raise: [_ | _] = exceptions}) do
    if e.__struct__ in exceptions do
      stacktrace = System.stacktrace()
      reraise e, stacktrace
    end

    error_with_stacktrace(e)
  end

  defp handle_exception(e, %{}), do: error_with_stacktrace(e)

  defp error_with_stacktrace(e), do: {:error, %{error: e, stacktrace: System.stacktrace()}}
end
