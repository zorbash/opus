defmodule Opus.Pipeline.Stage do
  @moduledoc """
  Specification of the stage behavior
  """

  # TODO: define type for opts

  @callback run(
              {
                module :: atom(),
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

  def maybe_run({module, _type, name, %{if: {_m, _f, _a} = condition}} = stage, input) do
    case Safe.apply(condition) do
      true ->
        do_run(stage, input)

      _ ->
        module.instrument(:stage_skipped, %{stage: %{pipeline: module, name: name}}, %{
          stage: name,
          input: input
        })

        # Ignore this stage
        :stage_skipped
    end
  end

  def maybe_run({_module, _type, _name, %{}} = stage, input), do: do_run(stage, input)

  def handle_run(:error, {module, name, input}),
    do:
      {:halt,
       {:error,
        %PipelineError{error: "Pipeline failed", pipeline: module, stage: name, input: input}}}

  def handle_run({:error, e}, {module, name, input}),
    do: {:halt, {:error, %PipelineError{error: e, pipeline: module, stage: name, input: input}}}

  def handle_run(:stage_skipped, {_module, _name, input}), do: {:cont, input}
  def handle_run(res, {_module, _name, _input}), do: {:cont, res}

  defp do_run({module, type, name, %{with: :anonymous, stage_id: id} = opts}, input) do
    callback = (module._opus_callbacks[id] |> Enum.find(fn %{type: t} -> t == :with end)).name
    do_run({module, type, name, %{opts | with: {module, callback, [input]}}}, input)
  end

  defp do_run({module, type, name, %{with: atom_with} = opts}, input)
       when is_atom(atom_with),
       do: do_run({module, type, name, %{opts | with: {module, atom_with, [input]}}}, input)

  defp do_run({_module, _type, _name, %{with: with_fun} = opts}, input)
       when is_function(with_fun),
       do: Safe.apply(with_fun, input, Map.take(opts, [:raise]))

  defp do_run({_module, _type, _name, %{with: {_m, _f, _a} = with_mfa} = opts}, _input),
    do: Safe.apply(with_mfa, Map.take(opts, [:raise]))

  defp do_run({module, type, name, %{} = opts}, input),
    do: do_run({module, type, name, Map.merge(opts, %{with: {module, name, [input]}})}, input)
end
