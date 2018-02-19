defmodule Opus.Pipeline.Stage.StepTest do
  use ExUnit.Case

  defmodule TestPipeline do
    use Opus.Pipeline

    step :explode, if: fn
      :boom -> true
      _ -> false
    end
    step :transform, with: &({:transformed, &1})
    step :next, with: &({:next, &1})

    def explode(_), do: {:error, :exploded}
  end

  alias TestPipeline, as: Subject

  describe "step step behavior" do
    test "with a successful step, runs the next step" do
      assert {:ok, {:next, {:transformed, :value}}} = Subject.call(:value)
    end

    test "with a step returning an error tuple it halts the pipeline" do
      assert {:error, %Opus.PipelineError{error: :exploded}} = Subject.call(:boom)
    end
  end

  describe "multiple definitions of the same name" do
    defmodule DuplicateStepPipeline do
      use Opus.Pipeline

      step :transform, with: &([&1])
      step :transform, with: &([&1 | &1])
      step :transform

      def transform(input), do: Enum.reverse(input)
    end

    test "it runs each step with its function" do
      assert {:ok, [:some, [:some]]} = DuplicateStepPipeline.call(:some)
    end
  end
end
