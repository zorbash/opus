defmodule Opus.SafeTest do
  use ExUnit.Case

  defmodule FixtureModule do
    def will_raise(_) do
      raise "some error"
    end

    def wont_raise(_) do
      :some_value
    end
  end

  alias Opus.Safe, as: Subject

  setup_all do
    fun = fn
      :will_raise -> raise "some error"
      :wont_raise -> :some_value
    end

    %{fun: fun}
  end

  describe "apply/2 with a module and no opts" do
    setup do
      {:ok, %{subject: &(Subject.apply({FixtureModule, &1, [:_]}))}}
    end

    test "when the function raises, it returns an error tuple", %{subject: subject} do
      assert {:error, %RuntimeError{message: "some error"}} = subject.(:will_raise)
    end

    test "when the function does not raise, it returns the return value of the function", %{subject: subject} do
      assert :some_value = subject.(:wont_raise)
    end
  end

  describe "apply/2 with a module and the :raise option is provided with a list of exceptions" do
    test "when it raises with an exception from the list, it is not rescued" do
      assert_raise RuntimeError, "some error", fn ->
        Subject.apply({FixtureModule, :will_raise, [:_]}, %{raise: [RuntimeError, ArithmeticError]})
      end
    end

    test "when it raises with an exception not in the list, it is rescued" do
      ret = Subject.apply({FixtureModule, :will_raise, [:_]}, %{raise: [ArgumentError, ArithmeticError]})

      assert {:error, %RuntimeError{}} = ret
    end

    test "when it does not raise, it returns the original return value" do
      ret = Subject.apply({FixtureModule, :wont_raise, [:_]}, %{raise: [ArgumentError, ArithmeticError]})

      assert ret == FixtureModule.wont_raise(:_)
    end
  end

  describe "apply/3 with a function and no options" do
    setup %{fun: fun} do
      {:ok, %{subject: &(Subject.apply(fun, &1))}}
    end

    test "when the function raises, it returns an error tuple", %{subject: subject} do
      assert {:error, %RuntimeError{message: "some error"}} = subject.(:will_raise)
    end

    test "when the function does not raise, it returns the return value of the function", %{subject: subject} do
      assert :some_value = subject.(:wont_raise)
    end
  end

  describe "apply/3 with a function and the %{raise: true} option" do
    test "when the function raises, the exception is not rescued", %{fun: fun} do
      assert_raise RuntimeError, "some error", fn ->
        Subject.apply(fun, :will_raise, %{raise: true})
      end
    end

    test "when the function does not raise, the return value of the function is returned", %{fun: fun} do
      assert Subject.apply(fun, :wont_raise, %{raise: true}) == fun.(:wont_raise)
    end
  end

  describe "apply/3 with a function and the :raise option is provided with a list of exceptions" do
    test "when the function raises with an exception from the list, it is not rescued" do
      assert_raise ArithmeticError, "bad argument in arithmetic expression", fn ->
        fun = fn _ -> raise ArithmeticError, "bad argument in arithmetic expression" end

        Subject.apply(fun, :_, %{raise: [ArgumentError, ArithmeticError]})
      end
    end

    test "when the function raises with an exception not in the list, it returns an error tuple" do
      fun = fn _ -> raise ArithmeticError, "bad argument in arithmetic expression" end
      assert {:error, %ArithmeticError{}} = Subject.apply(fun, :_, %{raise: [ArgumentError, RuntimeError]})
    end

    test "when the function does not raise, the return value of the function is returned", %{fun: fun} do
      assert Subject.apply(fun, :wont_raise, %{raise: [ArgumentError, RuntimeError]}) == fun.(:wont_raise)
    end
  end
end
