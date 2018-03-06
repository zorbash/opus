defmodule Opus.PipelineError do
  @moduledoc ~S"""
  Error struct capturing useful information to detect where an error was caused and why.
  """

  defexception [:error, :pipeline, :stage, :input]

  def message(%{error: error, pipeline: pipeline, stage: stage, input: input}) do
    "Pipeline #{inspect(pipeline)} failed at stage #{stage} with error: #{inspect(error)}, input #{
      inspect(input)
    }"
  end
end
