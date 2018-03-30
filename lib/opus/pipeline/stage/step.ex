defmodule Opus.Pipeline.Stage.Step do
  @moduledoc ~S"""
  The step stage defines an operation which is considered successful unless
  it returns an error atom `:error` or tuple `{:error, _}`.
  It is also considered failed and halts the pipeline when it raises an unexpected exception.
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run(stage, input) do
    stage |> Stage.maybe_run(input) |> Stage.handle_run(%{stage: stage, input: input})
  end
end
