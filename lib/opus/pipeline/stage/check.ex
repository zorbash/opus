defmodule Opus.Pipeline.Stage.Check do
  alias Opus.PipelineError
  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run({module, _, name, _opts} = stage, input) do
    case Stage.maybe_run(stage, input) do
      ret when ret in [true, :stage_skipped] -> {:cont, input}
      error -> {:halt, {:error, %PipelineError{error: "Check failed with: #{inspect error}", pipeline: module, stage: name, input: input}}}
    end
  end
end
