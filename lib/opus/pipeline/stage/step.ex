defmodule Opus.Pipeline.Stage.Step do
  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run({module, _, name, _opts} = stage, input) do
    Stage.maybe_run(stage, input) |> Stage.handle_run({module, name, input})
  end
end
