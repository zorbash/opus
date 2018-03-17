defmodule Opus.Instrumentation do
  @moduledoc false

  defmacro instrument(event, fun) do
    handling = __MODULE__.definstrument(fun)

    quote do
      @doc false
      def instrument(unquote(event), _, metrics), do: unquote(handling)
    end
  end

  defmacro instrument(event, opts, fun) do
    handling = __MODULE__.definstrument(fun)

    quote do
      @doc false
      def instrument(unquote(event), unquote(opts), metrics), do: unquote(handling)
    end
  end

  def definstrument(fun) do
    quote do
      case unquote(fun) do
        f when is_function(f, 0) -> f.()
        f when is_function(f, 1) -> f.(metrics)
      end
    end
  end

  def default_callback do
    quote do
      def instrument(_, _, _), do: :ok
    end
  end

  def run_instrumented({_module, _type, _name, %{instrument?: false}}, _input, fun)
      when is_function(fun, 0),
      do: fun.()

  def run_instrumented({_module, _type, name, _opts} = stage, input, fun) when is_function(fun, 0) do
    start = :erlang.monotonic_time()
    run_instrumenters(:before_stage, stage, %{stage: name, input: input})

    ret = fun.()

    run_instrumenters(:stage_completed, stage, %{
      stage: name,
      input: input,
      result: format_result(ret),
      time: :erlang.monotonic_time() - start
    })

    ret
  end

  def run_instrumenters(event, {module, _type, _name, _opts} = stage, metrics) do
    case Application.get_env(:opus, :instrumentation, []) do
      instrumenter when is_atom(instrumenter) ->
        do_run_instrumenters([module | [instrumenter]], event, stage, metrics)

      instrumenters when is_list(instrumenters) ->
        do_run_instrumenters([module | instrumenters], event, stage, metrics)

      _ ->
        do_run_instrumenters([module], event, stage, metrics)
    end
  end

  defp do_run_instrumenters(instrumenters, event, {module, _type, name, _opts}, metrics) do
    for instrumenter <- instrumenters, is_atom(instrumenter), function_exported?(instrumenter, :instrument, 3) do
      instrumenter.instrument(event, %{stage: %{pipeline: module, name: name}}, metrics)
    end
  end

  defp format_result({:cont, value}), do: {:ok, value}
  defp format_result({:halt, value}), do: {:error, value}
end
