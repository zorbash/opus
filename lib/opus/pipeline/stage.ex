defmodule Opus.Pipeline.Stage do
  @moduledoc """
  Specification of the stage behavior
  """

  @callback run(
              {
                module :: atom(),
                type :: atom(),
                name :: atom(),
                opts :: %{}
              },
              input :: any()
            ) :: {:cont | :halt, any()}

  alias Opus.{Safe, PipelineError}

  def maybe_run({module, type, name, %{if: :anonymous, stage_id: id} = opts}, input) do
    callback = (module._opus_callbacks[id] |> Enum.find(fn %{type: t} -> t == :if end)).name
    maybe_run({module, type, name, %{opts | if: {module, callback, [input]}}}, input)
  end

  def maybe_run({module, type, name, %{if: fun} = opts} = _stage, input)
      when is_atom(fun),
      do: maybe_run({module, type, name, %{opts | if: {module, fun, [input]}}}, input)

  def maybe_run({module, :skip, name, %{if: {_m, _f, _a} = condition}}, input) do
    case Safe.apply(condition) do
      true ->
        module.instrument(:pipeline_skipped, %{stage: %{pipeline: module, name: name}}, %{
          stage: name,
          input: input
        })

        # Stop the pipeline execution
        :pipeline_skipped

      _ ->
        nil
    end
  end

  def maybe_run({module, _type, name, %{if: {_m, _f, _a} = condition} = opts} = stage, input) do
    case Safe.apply(condition) do
      true ->
        with_retries({module, opts}, fn -> do_run(stage, input) end)

      _ ->
        module.instrument(:stage_skipped, %{stage: %{pipeline: module, name: name}}, %{
          stage: name,
          input: input
        })

        # Ignore this stage
        :stage_skipped
    end
  end

  def maybe_run({module, _type, _name, opts} = stage, input),
    do: with_retries({module, opts}, fn -> do_run(stage, input) end)

  def with_retries({module, %{retry_times: times, stage_id: id, retry_backoff: :anonymous}}, fun) do
    callback =
      (module._opus_callbacks[id] |> Enum.find(fn %{type: t} -> t == :retry_backoff end)).name

    with_retries(
      {module, %{retry_times: times, stage_id: id, retry_backoff: {module, callback, []}}},
      fun
    )
  end

  def with_retries({module, %{retry_times: times, stage_id: id, retry_backoff: backoff}}, fun)
      when is_atom(backoff) do
    with_retries(
      {module, %{retry_times: times, stage_id: id, retry_backoff: {module, backoff, []}}},
      fun
    )
  end

  def with_retries({module, %{retry_times: times, stage_id: id, retry_backoff: {m, f, a}}}, fun) do
    case Safe.apply(fn -> Enum.take(apply(m, f, a), times) end) do
      [_ | _] = delays ->
        with_retries({module, %{retry_times: times, stage_id: id, delays: delays}}, fun)

      _ ->
        with_retries({module, %{retry_times: times, stage_id: id}}, fun)
    end
  end

  def with_retries({module, %{retry_times: _times, stage_id: _id} = opts}, fun) do
    result = fun.()

    case result |> handle_run(%{stage: {:_, :_, :_, :_}, input: :_}) do
      {:halt, _} -> with_retries({module, opts}, fun, %{failures: 1})
      _ -> result
    end
  end

  def with_retries({_module, _opts}, fun), do: fun.()

  def with_retries({module, %{retry_times: times} = stage}, fun, %{failures: failures}) do
    delays =
      case stage[:delays] do
        [delay | delays] ->
          :timer.sleep(delay)
          delays

        other ->
          other
      end

    result = fun.()

    case {failures < times, result |> handle_run(%{stage: {:_, :_, :_, :_}, input: :_})} do
      {true, {:halt, _}} ->
        with_retries({module, put_in(stage[:delays], delays)}, fun, %{failures: failures + 1})

      {_, _} ->
        result
    end
  end

  def handle_run(:error, %{stage: {module, _type, name, %{error_message: message}}, input: input}) do
    {:halt, {:error, %PipelineError{error: message, pipeline: module, stage: name, input: input}}}
  end

  def handle_run(:error, %{stage: {module, _type, name, _opts}, input: input}),
    do:
      {:halt,
       {:error,
        %PipelineError{error: "stage failed", pipeline: module, stage: name, input: input}}}

  def handle_run({:error, e}, %{
        stage: {module, _type, name, %{error_message: message}},
        input: input
      }),
      do:
        {:halt,
         {:error,
          format_error(put_in(e[:error], message), %{pipeline: module, stage: name, input: input})}}

  def handle_run({:error, %Opus.PipelineError{} = e}, _) do
    {:halt, {:error, e}}
  end

  def handle_run({:error, e}, %{stage: {module, _type, name, _opts}, input: input}) do
    {:halt, {:error, format_error(e, %{pipeline: module, stage: name, input: input})}}
  end

  def handle_run(:stage_skipped, %{stage: _stage, input: input}), do: {:cont, input}
  def handle_run(res, %{stage: _stage, input: _input}), do: {:cont, res}

  defp format_error(%{error: e, stacktrace: trace}, %{pipeline: module, stage: name, input: input}) do
    %PipelineError{error: e, pipeline: module, stage: name, input: input, stacktrace: trace}
  end

  defp format_error(error, %{pipeline: module, stage: name, input: input}) do
    %PipelineError{error: error, pipeline: module, stage: name, input: input}
  end

  defp do_run({module, type, name, %{with: :anonymous, stage_id: id} = opts}, input) do
    callback = (module._opus_callbacks[id] |> Enum.find(fn %{type: t} -> t == :with end)).name
    do_run({module, type, name, %{opts | with: {module, callback, [input]}}}, input)
  end

  defp do_run({module, type, name, %{with: atom_with} = opts}, input)
       when is_atom(atom_with),
       do: do_run({module, type, name, %{opts | with: {module, atom_with, [input]}}}, input)

  defp do_run({module, _type, _name, %{with: with_fun} = opts}, input)
       when is_function(with_fun),
       do: Safe.apply(with_fun, input, Map.merge(module._opus_opts, Map.take(opts, [:raise])))

  defp do_run({module, _type, _name, %{with: {_m, _f, _a} = with_mfa} = opts}, _input),
    do: Safe.apply(with_mfa, Map.merge(module._opus_opts, Map.take(opts, [:raise])))

  defp do_run({module, type, name, %{} = opts}, input),
    do: do_run({module, type, name, Map.merge(opts, %{with: {module, name, [input]}})}, input)
end
