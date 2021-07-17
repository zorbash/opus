defmodule Opus.Pipeline.Stage.Tee do
  @moduledoc ~S"""
  The tee stage is intended for side-effects with no meaningful return value.

  Its return value is ignored and the next stage is always called.
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  @doc false
  def run(stage, input) do
    Stage.maybe_run(stage, input)

    {:cont, input}
  end
end
