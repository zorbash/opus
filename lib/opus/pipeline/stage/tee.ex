defmodule Opus.Pipeline.Stage.Tee do
  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run(stage, input) do
    Stage.maybe_run(stage, input)

    {:cont, input}
  end
end
