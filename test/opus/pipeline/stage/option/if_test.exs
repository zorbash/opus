defmodule Opus.Pipeline.Option.IfTest do
  use ExUnit.Case

  describe "as atom - when the condition is true" do
    defmodule PipelineWithTruthyAtomIf do
      use Opus.Pipeline

      step :double, if: :calculate?

      def double(n), do: n * 2
      def calculate?(_), do: true
    end

    alias PipelineWithTruthyAtomIf, as: Subject

    test "it returns the expected result" do
      assert {:ok, 10} = Subject.call(5)
    end
  end

  describe "as atom - when the condition is falsey" do
    defmodule PipelineWithFalseyAtomIf do
      use Opus.Pipeline

      step :double, if: :calculate?

      def double(n), do: n * 2
      def calculate?(_), do: false
    end

    alias PipelineWithFalseyAtomIf, as: Subject

    test "it returns the expected result" do
      assert {:ok, 5} = Subject.call(5)
    end
  end
end
