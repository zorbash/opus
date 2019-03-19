defmodule Opus.Pipeline.Stage.SkipTest do
  use ExUnit.Case

  describe "when the stage returns false and there's no next stage" do
    defmodule SingleSkipFalsePipeline do
      use Opus.Pipeline

      skip :some_name, if: :should_skip?

      def should_skip?(_), do: false
    end

    setup do
      {:ok, %{subject: SingleSkipFalsePipeline}}
    end

    test "returns a success tuple with the original input", %{subject: subject} do
      assert {:ok, 1} = subject.call(1)
    end
  end

  describe "when the stage returns false and there's another next stage" do
    defmodule SkipFalsePipeline do
      use Opus.Pipeline

      skip :some_name, if: :should_skip?
      step :sum_10, with: &(&1 + 10)

      def should_skip?(_), do: false
    end

    setup do
      {:ok, %{subject: SkipFalsePipeline}}
    end

    test "returns a success tuple with the expected final pipeline data", %{subject: subject} do
      assert {:ok, 11} = subject.call(1)
    end
  end

  describe "when skip returns true" do
    defmodule SkipTruePipeline do
      use Opus.Pipeline

      skip :some_name, if: :should_skip?
      step :shouldnt_be_called, with: fn _ -> raise "Shoudn't raise" end

      def should_skip?(_), do: true
    end

    setup do
      {:ok, %{subject: SkipTruePipeline}}
    end

    test "returns a success tuple with the input as the second value", %{subject: subject} do
      assert {:ok, 1} = subject.call(1)
    end
  end

  describe "when more than one skips are added to the pipeline and the first skip returns true" do
    defmodule MultiSkipFirstTruePipeline do
      use Opus.Pipeline

      skip :some_name, if: :hope_it_skips
      skip :some_other_name, if: :not_gonna_skip
      step :shouldnt_be_called, with: fn _ -> raise "Shouldn't raise" end

      def hope_it_skips(_), do: true
      def not_gonna_skip(_), do: false
    end

    setup do
      {:ok, %{subject: MultiSkipFirstTruePipeline}}
    end

    test "returns a success tuple with the input skipped as the second value", %{subject: subject} do
      assert {:ok, 1} = subject.call(1)
    end
  end

  describe "when more than one skips are added to the pipeline and the second one returns true" do
    defmodule MultiSkipSecondTruePipeline do
      use Opus.Pipeline

      skip :a_name, if: :wont_skip
      skip :other_name, if: :it_skips
      step :shouldnt_be_called, with: fn _ -> raise "Shouldn't raise" end

      def wont_skip(_), do: true
      def it_skips(_), do: false
    end

    setup do
      {:ok, %{subject: MultiSkipSecondTruePipeline}}
    end

    test "returns a success tuple with the input as the second value", %{subject: subject} do
      assert {:ok, 1} = subject.call(1)
    end
  end

  describe "when more than one skips are added to the pipeline and all them return false" do
    defmodule MultiSkipFalsePipeline do
      use Opus.Pipeline

      skip :some_name, if: :wont_skip
      skip :other_name, if: :other_wont_skip
      step :sum_10, with: &(&1 + 10)

      def wont_skip(_), do: false
      def other_wont_skip(_), do: false
    end

    setup do
      {:ok, %{subject: MultiSkipFalsePipeline}}
    end

    test "returns a success tuple with the expected final pipeline data", %{subject: subject} do
      assert {:ok, 11} = subject.call(1)
    end
  end

  describe "when the stage returns anything other than 'true' (boolean) and there's another next stage" do
    defmodule SkipFalseNonBooleanPipeline do
      use Opus.Pipeline

      skip :some_name, if: :should_skip?
      step :sum_10, with: &(&1 + 10)

      def should_skip?(_), do: "not a boolean"
    end

    setup do
      {:ok, %{subject: SkipFalseNonBooleanPipeline}}
    end

    test "returns a success tuple as if the skip stage has returned false and next stage is called",
         %{subject: subject} do
      assert {:ok, 11} = subject.call(1)
    end
  end

  describe "when linked by another module" do
    defmodule ItSkipsPipeline do
      use Opus.Pipeline, instrument?: false

      skip :some_name, if: fn _ -> true end
      step :raise, with: fn -> raise "I shouldn't be called" end
    end

    defmodule ItLinksPipeline do
      use Opus.Pipeline, instrument?: false

      step :double, with: &(&1 * 2)
      link ItSkipsPipeline
      step :triple, with: &(&1 * 3)
    end

    setup do
      {:ok, %{subject: ItLinksPipeline}}
    end

    test "foobar", %{subject: subject} do
      assert {:ok, 12} = subject.call(2)
    end
  end
end
