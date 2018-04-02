defmodule Opus.Pipeline.StageFilterTest do
  use ExUnit.Case

  alias Opus.Pipeline.StageFilter, as: Subject

  describe "call/2" do
    test "with an empty list of stages and no options, returns empty list" do
      assert [] = Subject.call([], %{})
    end

    test "with an empty list of stages and stages to reject, returns empty list" do
      assert [] = Subject.call([], %{except: [:some_stage]})
    end

    test "with an empty list of stages and stages to filter from, returns empty list" do
      assert [] = Subject.call([], %{only: [:some_stage]})
    end

    test "with a list of stages and stages to reject, returns a list without the rejected" do
      assert stages() |> Subject.call(%{except: [:send_notification]}) == [
               {:check, :validate_params, %{}},
               {:stage, :persist, %{}}
             ]
    end

    test "with a list of stages and stages to reject as an atom, returns a list without the rejected" do
      assert stages() |> Subject.call(%{except: :send_notification}) == [
               {:check, :validate_params, %{}},
               {:stage, :persist, %{}}
             ]
    end

    test "with a list of stages and the :only option, returns a list containing only matching stages" do
      assert stages() |> Subject.call(%{only: [:persist]}) == [{:stage, :persist, %{}}]
    end

    test "with a list of stages and the :only option as an atom, returns a list containing only matching stages" do
      assert stages() |> Subject.call(%{only: :persist}) == [{:stage, :persist, %{}}]
    end

    test "with a list of stages and :only and :except options, returns a list filtered by both options" do
      assert stages()
             |> Subject.call(%{only: [:persist, :send_notification], except: [:send_notification]}) ==
               [{:stage, :persist, %{}}]
    end

    test "with a list of stages and an invalid :only option, returns all stages" do
      assert stages() |> Subject.call(%{only: %{}}) == stages()
    end

    test "with a list of stages and an invalid :except option, returns all stages" do
      assert stages() |> Subject.call(%{except: %{}}) == stages()
    end
  end

  defp stages do
    [
      {:check, :validate_params, %{}},
      {:stage, :persist, %{}},
      {:tee, :send_notification, %{}}
    ]
  end
end
