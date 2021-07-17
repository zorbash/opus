defmodule Opus.Pipeline.Stage.Step do
  @moduledoc ~S"""
  The step stage defines an operation which is considered successful unless
  it returns either an error atom `:error` or tuple `{:error, _}`.

  It is also considered failed and halts the pipeline when it raises an unexpected exception.

  ## Example

      defmodule CryptoMarkerForecastPipeline do
        use Opus.Pipeline

        step :waste_time, with: (fn _ -> Process.sleep(10) end)
        step :calculate_lunar_phase
        step :fetch_elonmusks_tweets
        step :forecast

        # Step definitions can either be defined inline using the `with` option
        # or as module functions like below

        # Notice that all step functions expect a single argument.
        # The return value of a step becomes the input value of the next one.

        def calculate_lunar_phase(_) do
          ["🌑", "🌒", "🌓", "🌔", "🌖", "🌗", "🌘", "🌚", "🌜", "🌝"]
          |> Enum.random
        end

        def fetch_elonmusks_tweets(_), do: "Baby Doge, doo, doo, doo"

        def forecast(_) do
          if :random.uniform > 0.5 do
            :buy
          else
            :sell
          end
        end
      end

  The above pipeline module can be invoked with:

      CryptoMarkerForecastPipeline.call "anything"
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  @doc false
  def run(stage, input) do
    stage |> Stage.maybe_run(input) |> Stage.handle_run(%{stage: stage, input: input})
  end
end
