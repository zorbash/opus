defmodule Opus.PipelineTest do
  use ExUnit.Case

  defmodule TestMath do
    def square(number), do: number * number
  end

  defmodule LinkedPipeline do
    use Opus.Pipeline

    step :add_two

    def add_two(input), do: input + 2
  end

  defmodule NonPipelineModule do
  end

  defmodule ArithmeticPipeline do
    use Opus.Pipeline

    step :add_one
    step :failing_atom, if: :run_failing_atom?
    step :failing_tuple, if: :run_failing_tuple?
    step :failing_exception, if: :run_failing_exception?
    check :even?, if: :run_check_even?
    step :square, with: &TestMath.square/1
    tee :publish_number, if: fn _ -> true end
    step :double
    link LinkedPipeline
    link NonPipelineModule

    def add_one(input), do: input + 1
    def double(input), do: input * 2

    def run_failing_exception?(42), do: true
    def run_failing_exception?(_input), do: false
    def failing_exception(_input), do: raise("failed with exception")

    def run_failing_atom?(1337), do: true
    def run_failing_atom?(_input), do: false
    def failing_atom(_input), do: :error

    def run_failing_tuple?(1111), do: true
    def run_failing_tuple?(_input), do: false
    def failing_tuple(_input), do: {:error, "failing tuple"}

    def run_check_even?(input) when input in [2222, 3333], do: true
    def run_check_even?(_input), do: false
    def even?(input), do: rem(input, 2) == 0

    def publish_number(input) do
      send self(), {:tee, input}

      :error
    end
  end

  alias ArithmeticPipeline, as: Subject

  describe "pipeline?/0" do
    assert Subject.pipeline?() == true
  end

  describe "stages/0" do
    test "returns a List of stages" do
      stages = Subject.stages() |> Enum.map(fn {stage, name, _} -> {stage, name} end)

      assert stages == [
               {:step, :add_one},
               {:step, :failing_atom},
               {:step, :failing_tuple},
               {:step, :failing_exception},
               {:check, :even?},
               {:step, :square},
               {:tee, :publish_number},
               {:step, :double},
               {:link, Opus.PipelineTest.LinkedPipeline}
             ]
    end
  end

  describe "call/1" do
    test "when all stages are successful, returns an :ok tagged tuple" do
      assert {:ok, _} = Subject.call(1)
    end

    test "with a failed stage, returns an :error tagged tuple" do
      assert {:error, %Opus.PipelineError{}} = Subject.call(41)
    end

    test "with a failed stage, returns an :error tagged tuple with failure information" do
      {:error, %Opus.PipelineError{} = error} = Subject.call(41)

      assert %Opus.PipelineError{
               error: %RuntimeError{message: "failed with exception"},
               pipeline: Subject,
               stage: :failing_exception,
               input: 42
             } = error
    end
  end

  describe "call/1 with a failing atom" do
    test "returns an :error tagged tuple" do
      assert {:error, %Opus.PipelineError{}} = Subject.call(1336)
    end
  end

  describe "call/1 with a failing tagged tuple" do
    test "returns an :error tagged tuple" do
      assert {:error, %Opus.PipelineError{}} = Subject.call(1110)
    end
  end

  describe "without any stages" do
    defmodule NoStagesPipeline do
      use Opus.Pipeline
    end

    test "returns a success tuple with the original input" do
      assert {:ok, :anything} = NoStagesPipeline.call(:anything)
    end
  end
end
