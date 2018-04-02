defmodule Opus.Pipeline.StageFilter do
  @moduledoc ~S"""
  Module to refine the stages to be run in a pipeline.

  Options

  * `:except`: A list of names, or an atom of stages to skip
  * `:only`:  A list of names, or an atom of stages to keep
  """

  import Enum, only: [reject: 2, filter: 2]

  def call(stages, opts) do
    stages
    |> stage_filter(:except, opts[:except])
    |> stage_filter(:only, opts[:only])
  end

  defp stage_filter(stages, _type, nil), do: stages
  defp stage_filter(stages, type, name) when is_atom(name), do: stage_filter(stages, type, [name])

  defp stage_filter(stages, :except, [_ | _] = names),
    do: do_stage_filter(stages, &reject(&1, fn {_, name, _} -> name in names end))

  defp stage_filter(stages, :only, [_ | _] = names) do
    do_stage_filter(stages, &filter(&1, fn {_, name, _} -> name in names end))
  end

  defp stage_filter(stages, _, _), do: stages

  defp do_stage_filter(stages, fun), do: fun.(stages)
end
