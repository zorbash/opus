defmodule Opus.PipelineError do
  @moduledoc ~S"""
  Error struct capturing useful information to detect where an error was caused and why.
  """

  @type t :: %__MODULE__{
          error: any,
          input: any,
          pipeline: module,
          stage: atom,
          stacktrace: [{module, atom, non_neg_integer, keyword}]
        }

  defexception [:error, :pipeline, :stage, :input, :stacktrace]

  def message(%{error: error, pipeline: pipeline, stage: stage, input: input, stacktrace: trace}) do
    "Pipeline #{inspect(pipeline)} failed at stage #{stage} with error: #{inspect(error)}, input #{inspect(input)}, stacktrace: #{inspect(trace)}"
  end
end
