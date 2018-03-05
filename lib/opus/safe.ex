defmodule Opus.Safe do
  import Kernel, except: [apply: 2]

  def apply(mfa), do: apply(mfa, %{})

  def apply({m, f, a}, opts) do
    Kernel.apply(m, f, a)
  rescue
    e -> handle_exception(e, opts)
  end

  def apply(fun, arg, opts \\ %{}) when is_function(fun) do
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

    {:error, e}
  end

  defp handle_exception(e, %{}) do
    {:error, e}
  end
end
