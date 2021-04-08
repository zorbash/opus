defmodule Opus.Telemetry do
  @moduledoc ~S"""
  Emits telemetry events

  To enable this instrumentation module, update your config/config.exs file with:

      config :opus, :instrumentation, [Opus.Telemetry]

  ## Telemetry Events

  * `[:opus, :pipeline, :start]` - emitted when a pipeline module is called.
    * Measurement: `%{time: System.system_time()}`
    * Metadata: `%{pipeline: String.t()}`

  * `[:opus, :pipeline, :stage, :stop]` - emitted at the end of a stage.
    * Measurement: `%{duration: pos_integer()}`
    * Metadata: `%{pipeline: String.t(), stage: String.t()}`

  * `[:opus, :pipeline, :stop]` - emitted when a pipeline has been completed.
    * Measurement: `%{duration: pos_integer(), success: boolean()}`
    * Metadata: `%{pipeline: String.t()}`
  """
  def instrument(:pipeline_started, %{pipeline: pipeline}, %{input: _input}) do
    :telemetry.execute(
      [:opus, :pipeline, :start],
      %{time: System.system_time()},
      %{pipeline: inspect(pipeline)}
    )
  end

  def instrument(:stage_completed, %{stage: %{name: name, pipeline: pipeline}}, %{time: time}) do
    :telemetry.execute(
      [:opus, :pipeline, :stage, :stop],
      %{duration: time},
      %{pipeline: inspect(pipeline), stage: name}
    )
  end

  def instrument(:pipeline_completed, %{pipeline: pipeline}, %{result: {:ok, _}, time: time}) do
    emit_stop(%{pipeline: pipeline, success?: true, duration: time})
  end

  def instrument(:pipeline_completed, %{pipeline: pipeline}, %{result: {:error, _}, time: time}) do
    emit_stop(%{pipeline: pipeline, success?: false, duration: time})
  end

  def instrument(_, _, _), do: :ok

  defp emit_stop(%{pipeline: pipeline, success?: success?, duration: duration}) do
    :telemetry.execute(
      [:opus, :pipeline, :stop],
      %{duration: duration, success: success?},
      %{pipeline: inspect(pipeline)}
    )
  end
end
