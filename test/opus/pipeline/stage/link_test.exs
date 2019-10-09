defmodule Opus.Pipeline.Stage.LinkTest do
  use ExUnit.Case

  defmodule IncompatibleModule do
  end

  defmodule CompatiblePipeline do
    use Opus.Pipeline

    step :double,
      with: fn
        {:transformed, input} -> input * 2
        input -> input * 2
      end

    step :triple, with: &(&1 * 3)
  end

  defmodule FailingPipeline do
    use Opus.Pipeline

    check :fail?,
      with: fn
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
      assert {:error, %Opus.PipelineError{pipeline: FailingPipeline, stage: :fail?}} =
               Subject.call(0)
    end
  end

  describe "self-linking" do
    defmodule RecursivePipeline do
      use Opus.Pipeline

      step :double, with: &(&1 * 2)
      link RecursivePipeline, if: &(&1 < 10)
    end

    test "does not raise" do
      RecursivePipeline.call(1)
    end

    test "returns the expected result" do
      assert {:ok, 16} = RecursivePipeline.call(1)
    end
  end

  describe "linking unknown module" do
    test "raises CompileError" do
      assert_raise CompileError,
                   ~r/module NonExistent is not loaded and could not be found/,
                   fn ->
                     defmodule BadLinkPipeline do
                       use Opus.Pipeline

                       link NonExistent
                     end
                   end
    end
  end

  defmodule PipelineReturningAtomError do
    use Opus.Pipeline

    step :do_something

    def do_something(_) do
      {:error, "a message"}
    end
  end

  defmodule PipelineLinkingErrorAtom do
    use Opus.Pipeline

    link PipelineReturningAtomError, error_message: "custom message"
  end

  describe "linking a pipeline with a stage which returns :error" do
    alias PipelineLinkingErrorAtom, as: Subject

    test "returns an error with the correct error message" do
      assert {:error, %Opus.PipelineError{error: "custom message"}} = Subject.call(%{})
    end
  end
end
