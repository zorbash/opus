defmodule Opus.Pipeline.Stage.Step do
  @moduledoc ~S"""
  The step stage defines an operation which is considered successful unless
  it returns an error atom `:error` or tuple `{:error, _}`.
  It is also considered failed and halts the pipeline when it raises an unexpected exception.
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run({module, _, name, _opts} = stage, input) do
    stage |> Stage.maybe_run(input) |> Stage.handle_run({module, name, input})
  end
end
