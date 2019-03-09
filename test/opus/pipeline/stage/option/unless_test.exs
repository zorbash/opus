defmodule Opus.Pipeline.Option.UnlessTest do
  use ExUnit.Case

  describe "in :step, as atom, when the condition is truth" do
    defmodule PipelineWithTruthyAtomUnless do
      use Opus.Pipeline

      step :double, unless: :immutable?

      def double(n), do: n * 2
      def immutable?(_), do: true
    end

    alias PipelineWithTruthyAtomUnless, as: Subject

    test "it returns the expected result" do
      assert {:ok, 5} = Subject.call(5)
    end
  end

  describe "in :step, as atom, when the condition is falsey" do
    defmodule PipelineWithFalseyAtomUnless do
      use Opus.Pipeline

      step :double, unless: :immutable?

      def double(n), do: n * 2
      def immutable?(_), do: false
    end

    alias PipelineWithFalseyAtomUnless, as: Subject

    test "it returns the expected result" do
      assert {:ok, 10} = Subject.call(5)
    end
  end

  describe "in :step, as anonymous function, when the condition is truth" do
    defmodule PipelineWithTruthyFuncUnless do
      use Opus.Pipeline

      step :double, unless: fn _ -> true end

      def double(n), do: n * 2
    end

    alias PipelineWithTruthyFuncUnless, as: Subject

    test "it returns the expected result" do
      assert {:ok, 5} = Subject.call(5)
    end
  end

  describe "in :step, as anonymous function, when the condition is falsey" do
    defmodule PipelineWithFalseyFuncUnless do
      use Opus.Pipeline

      step :double, unless: fn _ -> false end

      def double(n), do: n * 2
    end

    alias PipelineWithFalseyFuncUnless, as: Subject

    test "it returns the expected result" do
      assert {:ok, 10} = Subject.call(5)
    end
  end
end
