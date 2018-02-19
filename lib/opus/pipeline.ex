defmodule Opus.Pipeline do
  defmacro __using__(_opts) do
    quote location: :keep do
      import Opus.Pipeline
      import Opus.Pipeline.Registration
      Module.register_attribute(__MODULE__, :opus_stages, accumulate: true)
      Module.register_attribute(__MODULE__, :opus_callbacks, accumulate: true)
      @before_compile Opus.Pipeline

      alias Opus.PipelineError
      alias Opus.Instrumentation
      alias Opus.Pipeline.Stage.{Step, Tee, Check, Link}
      alias __MODULE__, as: Pipeline

      import Opus.Instrumentation, only: :macros

      def pipeline?, do: true

      def call(input) do
        case Pipeline.stages |> Enum.reduce_while(input, &run_instrumented/2) do
          {:error, _} = error -> error
          val -> {:ok, val}
        end
      end

      defp run_instrumented({type, name, opts} = stage, input),
        do: Instrumentation.run_instrumented({Pipeline, type, name, opts}, input, (fn -> run_stage(stage, input) end))

      defp run_stage({type, name, opts}, input), do: run_stage({Pipeline, type, name, opts}, input)
      defp run_stage({module, :step, name, opts} = stage, input), do: Step.run(stage, input)
      defp run_stage({module, :tee, name, opts} = stage, input), do: Tee.run(stage, input)
      defp run_stage({module, :check, name, opts} = stage, input), do: Check.run(stage, input)
      defp run_stage({module, :link, name, opts} = stage, input), do: Link.run(stage, input)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    default_instrumentation = Opus.Instrumentation.default_callback()

    quote do
      def stages, do: @opus_stages |> Enum.reverse
      @opus_grouped_callbacks @opus_callbacks |> Enum.group_by(&(&1.stage_id))
      def _opus_callbacks, do: @opus_grouped_callbacks
      unquote(default_instrumentation)
    end
  end

  defmacro link(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      if :erlang.function_exported(unquote(name), :pipeline?, 0) do
        unquote(callbacks)
        options = Opus.Pipeline.Registration.normalize_opts(unquote(opts), unquote(stage_id), @opus_callbacks)
        @opus_stages {:link, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
      else
        #IO.warn "Expected #{inspect mod} to be an Opus.Pipeline module. Did you forget to add: `use Opus.Pipeline`?"
      end
    end
  end

  defmacro step(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)
      options = Opus.Pipeline.Registration.normalize_opts(unquote(opts), unquote(stage_id), @opus_callbacks)
      @opus_stages {:step, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end

  defmacro tee(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)
      options = Opus.Pipeline.Registration.normalize_opts(unquote(opts), unquote(stage_id), @opus_callbacks)
      @opus_stages {:tee, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end

  defmacro check(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)
      options = Opus.Pipeline.Registration.normalize_opts(unquote(opts), unquote(stage_id), @opus_callbacks)
      @opus_stages {:check, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end
end
