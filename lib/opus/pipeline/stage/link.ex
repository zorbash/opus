defmodule Opus.Pipeline.Stage.Link do
  @moduledoc ~S"""
  The link stage calls the specified pipeline module.

  When defined with a non `Opus.Pipeline` module, it ignores it.

  ## Example

      defmodule AddOnePipeline do
        use Opus.Pipeline

        step :add, with: &(&1 + 1)
      end

      defmodule MultiplicationPipeline do
        use Opus.Pipeline

        step :double, with: &(&1 * 2)
        link AddOnePipeline
      end

      MultiplicationPipeline.call 5
      # {:ok, 11}
  """

  alias Opus.Pipeline.Stage
  alias Opus.Pipeline.Stage.Step

  @behaviour Stage

  @doc false
  def run({module, type, name, opts}, input) do
    case Step.run({module, type, name, Map.merge(opts, %{with: &name.call/1})}, input) do
      {:cont, {:ok, val}} -> {:cont, val}
      {:cont, val} -> {:cont, val}
      {:halt, {:error, err}} -> {:halt, {:error, err}}
    end
  end
end
