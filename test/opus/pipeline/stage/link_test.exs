defmodule Opus.Pipeline.Stage.LinkTest do
  use ExUnit.Case

  defmodule IncompatibleModule do
  end

  defmodule CompatiblePipeline do
    use Opus.Pipeline

    step :double, with: fn
      {:transformed, input} -> input * 2
      input -> input * 2
    end

    step :triple, with: &(&1 * 3)
  end

  defmodule FailingPipeline do
    use Opus.Pipeline

    check :fail?, with: fn
      0 -> false
      _ -> true
    end
  end

  defmodule LinkPipeline do
    use Opus.Pipeline

    step :transform
    link CompatiblePipeline, if: fn _ -> true end
    link CompatiblePipeline
    link FailingPipeline
    link IncompatibleModule

    def transform(input) do
      {:transformed, input}
    end
  end

  alias LinkPipeline, as: Subject

  describe "link stage behavior" do
    test "runs the stages of a compatible linked module" do
      assert {:ok, 36} = Subject.call(1)
    end

    test "with a failing linked module, it fails the pipeline" do
      assert {:error, %Opus.PipelineError{pipeline: FailingPipeline, stage: :fail?}} = Subject.call(0)
    end
  end

  describe "self-linking" do
    defmodule RecursivePipeline do
      use Opus.Pipeline

      step :double, with: &(&1 * 2)
      link RecursivePipeline, if: &(&1 < 10)
    end

    test "does not raise" do
      Subject.call(1)
    end
  end
end
