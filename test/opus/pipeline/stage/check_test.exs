defmodule Opus.Pipeline.Stage.CheckTest do
  use ExUnit.Case

  describe "when the stage returns true and there's no next stage" do
    defmodule SingleCheckTruePipeline do
      use Opus.Pipeline

      check :odd?, with: &(rem(&1, 2) == 1)
    end

    setup do
      {:ok, %{subject: SingleCheckTruePipeline}}
    end

    test "returns a success tuple with the original input", %{subject: subject} do
      assert {:ok, 1} = subject.call(1)
    end
  end

  describe "when the stage does not return true and there's no next stage" do
    defmodule SingleCheckFalsePipeline do
      use Opus.Pipeline

      check :not_true,
        with: fn
          false -> false
          :falsy -> nil
          :other -> %{}
        end
    end

    setup do
      {:ok, %{subject: SingleCheckFalsePipeline}}
    end

    test "with false, returns an error tuple with an error message", %{subject: subject} do
      assert {:error, %Opus.PipelineError{error: :failed_check_not_true}} = subject.call(false)
    end

    test "with false, returns an error tuple", %{subject: subject} do
      assert {:error, %Opus.PipelineError{stage: :not_true}} = subject.call(false)
    end

    test "with falsy, returns an error tuple", %{subject: subject} do
      assert {:error, %Opus.PipelineError{stage: :not_true}} = subject.call(:falsy)
    end

    test "with a return value other than true, returns an error tuple", %{subject: subject} do
      assert {:error, %Opus.PipelineError{stage: :not_true}} = subject.call(:other)
    end
  end

  describe "when the stage returns true and there's a next stage" do
    defmodule CheckTruePipeline do
      use Opus.Pipeline

      check :odd?, with: &(rem(&1, 2) == 1)
      step :double, with: &(&1 * 2)
    end

    setup do
      {:ok, %{subject: CheckTruePipeline}}
    end

    test "calls the next stage", %{subject: subject} do
      assert {:ok, 2} = subject.call(1)
    end
  end
end
