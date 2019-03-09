defmodule Opus.Pipeline.StageTest do
  use ExUnit.Case

  defmodule Backoffs do
    import Retry.DelayStreams

    def backoff(n \\ 10) do
      Stream.unfold(1, fn failures ->
        {:erlang.round(n * :math.pow(3, failures)), failures + 1}
      end)
    end

    def invalid do
      :error
    end
  end

  describe ":with option - atom" do
    defmodule PipelineWithAtomWith do
      use Opus.Pipeline

      step :double, with: :double

      def double(n), do: n * 2
    end

    alias PipelineWithAtomWith, as: Subject

    test "it returns the expected result" do
      assert {:ok, 10} = Subject.call(5)
    end
  end

  describe "retries - anonymous backoff function" do
    defmodule PipelineWithRetries do
      use Opus.Pipeline

      step :http_request, retry_times: 3, retry_backoff: fn -> 10 |> linear_backoff(40) |> cap(100) end

      def http_request(:fail) do
        send self(), {:http_request, :os.timestamp()}

        {:error, "this was meant to fail"}
      end

      def http_request(:succeed) do
        send self(), {:http_request, :os.timestamp()}

        :success
      end
    end

    alias PipelineWithRetries, as: Subject

    test "when a stage fails always, it is retried the specified number of times" do
      assert {:error, %{error: "this was meant to fail"}} = Subject.call(:fail)

      assert_received {:http_request, _}

      for _ <- 1..3 do
        assert_received {:http_request, _}
      end

      refute_received {:http_request, _}
    end

    test "when a stage fails always, it is retried with the expected backoffs" do
      start_time = :os.timestamp()
      Subject.call(:fail)

      messages = Process.info(self(), [:messages])[:messages]
      [t1, t2, t3, t4 | _] = for {:http_request, t} <- messages, do: t

      assert_in_delta 0, time_diff(t1, start_time), 10

      # linear_backoff values
      assert_in_delta 10, time_diff(t2, t1), 10
      assert_in_delta 50, time_diff(t3, t2), 10
      assert_in_delta 90, time_diff(t4, t3), 10
    end

    test "when a stage succeeds, it is not retried" do
      Subject.call(:succeed)

      assert_received {:http_request, _}
      refute_received {:http_request, _}
    end
  end

  describe "retries - backoff function reference" do
    defmodule PipelineWithRetriesBackoffFunctionReference do
      use Opus.Pipeline

      step :total_failure,
        if: &(!match?(:skip_total_failure, &1)),
        with: fn _ ->
          send self(), {:total_failure, :os.timestamp()}
          :error
        end,
        retry_times: 3,
        retry_backoff: &Backoffs.backoff/0

      step :invalid_backoff,
        with: fn _ ->
          send self(), {:invalid_backoff, :os.timestamp()}
          :error
        end,
        retry_times: 3,
        retry_backoff: &Backoffs.invalid/0

      step :total_success,
        with: fn _ -> send self(), {:total_success, :os.timestamp()} end,
        retry_times: 3,
        retry_backoff: &Backoffs.backoff/0
    end

    alias PipelineWithRetriesBackoffFunctionReference, as: Subject

    test "with a backoff function returning a Stream, it retries the correct number of times" do
      Subject.call(:_)

      assert_receive {:total_failure, _}

      for _ <- 1..3 do
        assert_receive {:total_failure, _}
      end

      refute_receive {:total_failure, _}
    end

    test "with a backoff function returning a Stream, retries with the correct delays" do
      start_time = :os.timestamp()
      Subject.call(:_)

      messages = Process.info(self(), [:messages])[:messages]
      [t1, t2, t3, t4 | _] = for {:total_failure, t} <- messages, do: t

      assert_in_delta 0, time_diff(t1, start_time), 10

      # Backoff.backoff values
      assert_in_delta 30, time_diff(t2, t1), 10
      assert_in_delta 90, time_diff(t3, t2), 10
      assert_in_delta 270, time_diff(t4, t3), 10
    end

    test "with an invalid backoff function returning a Stream, it retries the correct number of times" do
      Subject.call(:skip_total_failure)

      assert_receive {:invalid_backoff, _}

      for _ <- 1..3 do
        assert_receive {:invalid_backoff, _}
      end

      refute_receive {:invalid_backoff, _}
    end

    test "with an invalid backoff function returning a Stream, it does not apply delays" do
      Subject.call(:skip_total_failure)

      assert_receive {:invalid_backoff, _}

      assert_receive {:invalid_backoff, t1}
      assert_receive {:invalid_backoff, t2}

      assert_in_delta 0, time_diff(t2, t1), 5
    end
  end

  describe "retries - backoff atom reference" do
    defmodule PipelineWithRetriesBackoffAtomReference do
      use Opus.Pipeline

      step :total_failure,
        if: &(!match?(:skip_total_failure, &1)),
        with: fn _ ->
          send self(), {:total_failure, :os.timestamp()}
          :error
        end,
        retry_times: 3,
        retry_backoff: :backoff

      step :invalid_backoff,
        with: fn _ ->
          send self(), {:invalid_backoff, :os.timestamp()}
          :error
        end,
        retry_times: 3,
        retry_backoff: :invalid_backoff

      step :total_success,
        with: fn _ -> send self(), {:total_success, :os.timestamp()} end,
        retry_times: 3,
        retry_backoff: :backoff

      def backoff, do: 10 |> linear_backoff(50) |> cap(150)
      def invalid_backoff, do: Backoffs.invalid_backoff()
    end

    alias PipelineWithRetriesBackoffAtomReference, as: Subject

    test "with a backoff function returning a Stream, it retries the correct number of times" do
      Subject.call(:_)

      assert_receive {:total_failure, _}

      for _ <- 1..3 do
        assert_receive {:total_failure, _}
      end

      refute_receive {:total_failure, _}
    end

    test "with a backoff function returning a Stream, retries with the correct delays" do
      start_time = :os.timestamp()
      Subject.call(:_)

      messages = Process.info(self(), [:messages])[:messages]
      [t1, t2, t3, t4 | _] = for {:total_failure, t} <- messages, do: t

      assert_in_delta 0, time_diff(t1, start_time), 10
      assert_in_delta 10, time_diff(t2, t1), 10
      assert_in_delta 60, time_diff(t3, t2), 10
      assert_in_delta 110, time_diff(t4, t3), 10
    end

    test "with an invalid backoff function returning a Stream, it retries the correct number of times" do
      Subject.call(:skip_total_failure)

      assert_receive {:invalid_backoff, _}

      for _ <- 1..3 do
        assert_receive {:invalid_backoff, _}
      end

      refute_receive {:invalid_backoff, _}
    end

    test "with an invalid backoff function returning a Stream, it does not apply delays" do
      Subject.call(:skip_total_failure)

      assert_receive {:invalid_backoff, _}

      assert_receive {:invalid_backoff, t1}
      assert_receive {:invalid_backoff, t2}

      assert_in_delta 0, time_diff(t2, t1), 5
    end
  end

  describe ":error_message option, with a message" do
    defmodule ErrorMessagePipeline do
      use Opus.Pipeline

      check :fail,
        if: &match?(:check_input, &1),
        with: fn _ -> false end,
        error_message: :failed_check

      step :double, error_message: :failed_to_double
      step :maybe_fail

      def double(n) when is_number(n), do: n * 2
      def maybe_fail(10), do: raise("this will fail")
      def maybe_fail(n), do: n
    end

    alias ErrorMessagePipeline, as: Subject

    test "when the stage fails, the original error message is replaced with the :error_message option" do
      assert {:error, %Opus.PipelineError{error: :failed_to_double}} = Subject.call(:not_a_number)
    end

    test "when the stage fails and no :error_message option is set, returns the original error" do
      assert {:error, %Opus.PipelineError{error: %RuntimeError{message: "this will fail"}}} =
               Subject.call(5)
    end

    test "when a check fails returns the :error_message option" do
      assert {:error, %Opus.PipelineError{error: :failed_check}} = Subject.call(:check_input)
    end
  end

  def time_diff(t2, t1) do
    :timer.now_diff(t2, t1) / 1000
  end
end
