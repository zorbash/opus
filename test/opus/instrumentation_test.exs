defmodule Opus.InstrumentationTest do
  use ExUnit.Case

  defmodule InstrumentedPipeline do
    use Opus.Pipeline

    step :add_one
    step :add_two
    step :add_three, with: &(&1 + 3), if: fn _ -> false end
    step :add_four, with: &(&1 + 4), instrument?: false

    instrument :before_stage, info, fn
      %{stage: _stage, input: -1} ->
        raise "oh noes"

      %{stage: _stage} = metrics ->
        send :instrumentation_test,
             {:erlang.unique_integer([:positive]), :before_stage, info, metrics}
    end

    instrument :stage_completed, info, fn %{time: _time} = metrics ->
      send :instrumentation_test,
           {:erlang.unique_integer([:positive]), :stage_completed, info, metrics}
    end

    instrument :stage_skipped, info, fn %{stage: _stage} = metrics ->
      send :instrumentation_test,
           {:erlang.unique_integer([:positive]), :stage_skipped, info, metrics}
    end

    def add_one(input) do
      send :instrumentation_test, {:erlang.unique_integer([:positive]), :stage, :add_one}
      input + 1
    end

    def add_two(input) do
      send :instrumentation_test, {:erlang.unique_integer([:positive]), :stage, :add_two}
      input + 2
    end
  end

  defmodule MockInstrumentation do
    def instrument(event, info, metrics) do
      send :instrumentation_test,
           {:erlang.unique_integer([:positive]), __MODULE__, event, info, metrics}
    end
  end

  alias InstrumentedPipeline, as: Subject

  setup do
    Process.register(self(), :instrumentation_test)

    on_exit fn ->
      Application.put_env(:opus, :instrumentation, nil)
    end

    :ok
  end

  describe "instrumentation - :before_stage" do
    test "it is called before the stage" do
      Subject.call(0)

      assert_received {t1, :before_stage, %{stage: %{name: :add_one}}, _metrics}
      assert_received {t2, :stage, :add_one}
      assert t1 < t2
    end

    test "it is called even when the stage is skipped" do
      Subject.call(0)

      assert_received {_, :before_stage, %{stage: %{name: :add_three}}, _metrics}
    end

    test "it yields the stage name" do
      Subject.call(0)

      assert_received {_, :before_stage, %{stage: %{name: :add_one}}, _metrics}
      assert_received {_, :before_stage, %{stage: %{name: :add_two}}, _metrics}
      assert_received {_, :before_stage, %{stage: %{name: :add_three}}, _metrics}
    end

    test "it yields the pipeline module" do
      Subject.call(0)

      assert_received {_, :before_stage, %{stage: %{pipeline: Subject}}, _metrics}
    end

    test "when the function raises an exception, it is not rescued" do
      assert_raise RuntimeError, fn ->
        Subject.call(-1)
      end
    end

    test "when a stage has instrument?: false, it is not called" do
      Subject.call(0)

      refute_received {_, :before_stage, %{stage: :add_four}, _}
    end

    test "the metrics key includes the input value of the stage" do
      Subject.call(0)

      assert_received {_, :before_stage, %{stage: %{name: :add_one}}, %{input: 0}}
    end

    test "when an instrumentation module is provided in application config as atom, it is called" do
      Application.put_env(:opus, :instrumentation, MockInstrumentation)
      Subject.call(0)

      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_one}}, _}
      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_two}}, _}
      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_three}}, _}
    end

    test "when an instrumentation module is provided in application config as list of atoms, it is called" do
      Application.put_env(:opus, :instrumentation, [MockInstrumentation])
      Subject.call(0)

      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_one}}, _}
      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_two}}, _}
      assert_received {_, MockInstrumentation, :before_stage, %{stage: %{name: :add_three}}, _}
    end
  end

  describe "intrumentation - :stage_completed" do
    test "it is called after the stage" do
      Subject.call(0)

      assert_received {t1, :stage, :add_one}
      assert_received {t2, :stage_completed, %{stage: %{name: :add_one}}, _metrics}
      assert t1 < t2
    end

    test "it is called even when the stage is skipped" do
      Subject.call(0)

      assert_received {_, :stage_completed, %{stage: %{name: :add_three}}, _metrics}
    end

    test "it yields the stage name" do
      Subject.call(0)

      assert_received {_, :stage_completed, %{stage: %{name: :add_one}}, _metrics}
      assert_received {_, :stage_completed, %{stage: %{name: :add_two}}, _metrics}
      assert_received {_, :stage_completed, %{stage: %{name: :add_three}}, _metrics}
    end

    test "it yields the pipeline module" do
      Subject.call(0)

      assert_received {_, :stage_completed, %{stage: %{pipeline: Subject}}, _metrics}
    end

    test "the metrics include the input value of the stage" do
      Subject.call(0)

      assert_received {_, :stage_completed, %{stage: %{name: :add_one}}, %{input: 0}}
    end

    test "the metrics include the time it took for the stage to be completed" do
      Subject.call(0)

      assert_received {_, :stage_completed, %{stage: %{name: :add_one}}, %{time: time}}
      assert time > 0
    end

    test "when a stage has instrument?: false, it is not called" do
      Subject.call(0)

      refute_received {_, :stage_completed, %{stage: %{name: :add_four}}}
    end

    test "when an instrumentation module is provided in application config as atom, it is called" do
      Application.put_env(:opus, :instrumentation, MockInstrumentation)
      Subject.call(0)

      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_one}}, _}
      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_two}}, _}
      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_three}}, _}
    end

    test "when an instrumentation module is provided in application config as list of atoms, it is called" do
      Application.put_env(:opus, :instrumentation, [MockInstrumentation])
      Subject.call(0)

      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_one}}, _}
      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_two}}, _}
      assert_received {_, MockInstrumentation, :stage_completed, %{stage: %{name: :add_three}}, _}
    end

    test "when an invalid instrumentation module is provided in application config, it does not raise" do
      Application.put_env(:opus, :instrumentation, "not a module")
      Subject.call(0)
    end

    test "when a list of invalid instrumentation modules in the application config, it does not raise" do
      Application.put_env(:opus, :instrumentation, ["not a module", "also not a module"])
      Subject.call(0)
    end
  end

  describe "intrumentation - :stage_skipped" do
    test "is is called when the stage is skipped" do
      Subject.call(0)

      assert_received {_, :stage_skipped, %{stage: %{name: :add_three}}, _}
    end

    test "it is not called when the stage is not skipped" do
      Subject.call(0)

      refute_received {_, :stage_skipped, %{stage: %{name: :add_one}}, _}
    end

    test "the metrics include the input value of the stage" do
      Subject.call(0)

      assert_received {_, :stage_skipped, %{stage: %{name: :add_three}}, %{input: input}}
      assert is_number(input)
    end
  end
end
