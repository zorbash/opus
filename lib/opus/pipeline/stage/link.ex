defmodule Opus.Pipeline.Stage.Link do
  alias Opus.Pipeline.Stage
  alias Opus.Pipeline.Stage.Step

  @behaviour Stage

  def run({module, type, name, opts}, input) do
    case Step.run({module, type, name, Map.merge(opts, %{with: &name.call/1})}, input) do
      {:cont, {:ok, val}} -> {:cont, val}
      {:halt, {:error, err}} -> {:halt, {:error, err.error}}
    end
  end
end
