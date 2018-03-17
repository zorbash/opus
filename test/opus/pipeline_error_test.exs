defmodule Opus.PipelineErrorTest do
  use ExUnit.Case

  alias Opus.PipelineError, as: Subject

  describe "error message" do
    test "it has info for the pipeline module stage and error" do
      error = %Subject{error: %RuntimeError{}, pipeline: :pipeline, stage: :stage, input: 42}

      assert Subject.message(error) == ~s"""
      Pipeline :pipeline failed at stage stage with error: %RuntimeError{message: "runtime error"}, input 42
      """
      |> String.trim
    end
  end
end
