defmodule Opus.PipelineError do
  defexception [:error, :pipeline, :stage, :input]

  def message(%{error: error, pipeline: pipeline, stage: stage, input: input}) do
    "Pipeline #{inspect(pipeline)} failed at stage #{stage} with error: #{inspect(error)}, input #{
      inspect(input)
    }"
  end
end
