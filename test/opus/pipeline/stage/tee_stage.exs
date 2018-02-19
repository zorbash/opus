defmodule Opus.Pipeline.Stage.TeeTest do
  use ExUnit.Case

  defmodule TeePipeline do
    use Opus.Pipeline

    tee :sideffect, with: fn
      :raise -> raise "oops"
      :ok -> :ok
      :error -> :error
      :error_tuple -> {:error, :error}
    end

    step :next, with: &({:next, &1})
  end

  alias TeePipeline, as: Subject

  describe "tee stage behaviour" do
    test "when it raises, the next stage is executed" do
      assert {:ok, {:next, _}} = Subject.call(:raise)
    end

    test "when it returns :error, the next stage is executed" do
      assert {:ok, {:next, _}} = Subject.call(:error)
    end

    test "when it returns an :error tuple, the next stage is executed" do
      assert {:ok, {:next, _}} = Subject.call(:error_tuple)
    end
  end
end
