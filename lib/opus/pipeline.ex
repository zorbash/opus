defmodule Opus.Pipeline do
  @moduledoc ~S"""
  Defines a pipeline.

  A pipeline defines a single entry point function to start running the defined stages.

  A simple pipeline module can be defined as:

      defmodule ArithmeticPipeline do
        use Opus.Pipeline

        step :to_integer, with: &:erlang.binary_to_integer/1
        step :double, with: & &1 * 2
      end

      # Invoke it with:
      ArithmeticPipeline.call "42"
      # => {:ok, 84}

  The pipeline can be run calling a `call/1` function which is defined by `Opus.Pipeline`.
  Pipelines are intended to have a single parameter and always return a tagged tuple `{:ok, value} | {:error, error}`.
  A stage returning `{:error, error}` halts the pipeline. The error value is an `Opus.PipelineError` struct which
  contains useful information to detect where the error was caused and why.

  ## Stage Definition

  The following types of stages can be defined:

  * `step`  - see `Opus.Pipeline.Stage.Step`
  * `tee`   - see `Opus.Pipeline.Stage.Tee`
  * `check` - see `Opus.Pipeline.Stage.Check`
  * `link`  - see `Opus.Pipeline.Stage.Link`
  * `skip`  - see `Opus.Pipeline.Stage.Skip`

  ## Stage Options

  * `:with`: The function to call to fulfill this stage. It can be an Atom
    referring to a public function of the module, an anonymous function or
    a function reference.
  * `:if`: Makes a stage conditional, it can be either an Atom referring
    to a public function of the module, an anonymous function or a
    function reference. For the stage to be executed, the condition *must*
    return `true`. When the stage is skipped, the input is forwarded to
    the next step if there's one.
  * `:unless`: The opposite of the `:if` option, executes the step only
      when the callback function returns `false`.
  * `:raise`: A list of exceptions to not rescue. Defaults to `false`
    which converts all exceptions to `{:error, %Opus.PipelineError{}}`
    values halting the pipeline.
  * `:error_message`: An error message to replace the original error when a
    stage fails. It can be a String or Atom, which will be used directly in place
    of the original message, or an anonymous function, which receives the input
    of the failed stage and must return the error message to be used.
  * `:retry_times`: How many times to retry a failing stage, before
    halting the pipeline.
  * `:retry_backoff`: A backoff function to provide delay values for
    retries. It can be an Atom referring to a public function in the
    module, an anonymous function or a function reference. It must return
    an `Enumerable.t` yielding at least as many numbers as the
    `retry_times`.
  * `:instrument?`: A boolean which defaults to `true`. Set to `false` to
    skip instrumentation for a stage.

  ## Exception Handling

  All exceptions are converted to `{:error, exception}` tuples by default.
  You may let a stage raise an exception by providing the `:raise` option to a stage as follows:

      defmodule ArithmeticPipeline do
        use Opus.Pipeline

        step :to_integer, &:erlang.binary_to_integer/1, raise: [ArgumentError]
      end

  ## Stage Filtering

  You can select the stages of a pipeline to run using `call/2` with the `:except` and `:only` options.
  Example:

  ```
  # Runs only the stage with the :validate_params name
  CreateUserPipeline.call(params, only: [:validate_params]
  # Runs all the stages except the selected ones
  CreateUserPipeline.call(params, except: :send_notification)
  ```
  """
  @type opts :: [only: [atom], except: [atom]]
  @type result :: {:ok, any} | {:error, Opus.PipelineError.t()}

  defmacro __using__(opts) do
    quote location: :keep do
      import Opus.Pipeline
      import Opus.Pipeline.Registration
      import Retry.DelayStreams

      Module.register_attribute(__MODULE__, :opus_stages, accumulate: true)
      Module.register_attribute(__MODULE__, :opus_callbacks, accumulate: true)
      @before_compile Opus.Pipeline
      @opus_opts Map.new(unquote(opts))

      alias Opus.PipelineError
      alias Opus.Instrumentation
      alias Opus.Pipeline.StageFilter
      alias Opus.Pipeline.Stage.{Step, Tee, Check, Link, Skip}
      alias __MODULE__, as: Pipeline

      import Opus.Instrumentation, only: :macros

      @doc false
      def pipeline?, do: true

      @doc "The entrypoint function of the pipeline"
      @spec call(any, Opus.Pipeline.opts()) :: Opus.Pipeline.result()
      def call(input, opts \\ []) do
        instrument? = Pipeline._opus_opts()[:instrument?]

        unless instrument? == false do
          Instrumentation.run_instrumenters(:pipeline_started, {Pipeline, nil, nil, nil}, %{
            input: input
          })
        end

        case Pipeline.stages()
             |> StageFilter.call(opts)
             |> Enum.reduce_while(%{time: 0, input: input}, &run_instrumented/2) do
          %{time: time, input: {:error, _} = error} ->
            unless instrument? == false do
              Instrumentation.run_instrumenters(:pipeline_completed, {Pipeline, nil, nil, nil}, %{
                result: error,
                time: time
              })
            end

            error

          %{time: time, input: val} ->
            unless instrument? == false do
              Instrumentation.run_instrumenters(:pipeline_completed, {Pipeline, nil, nil, nil}, %{
                result: {:ok, val},
                time: time
              })
            end

            {:ok, val}
        end
      end

      @doc false
      def _opus_opts, do: @opus_opts

      defp run_instrumented({type, name, opts} = stage, %{time: acc_time, input: input}) do
        pipeline_opts = Pipeline._opus_opts()

        instrumented_return =
          Instrumentation.run_instrumented(
            {Pipeline, type, name, Map.merge(pipeline_opts, opts)},
            input,
            fn ->
              run_stage(stage, input)
            end
          )

        case instrumented_return do
          {status, %{time: time, input: :pipeline_skipped}} ->
            {status, %{time: acc_time + time, input: input}}

          {status, %{time: time, input: new_input}} ->
            {status, %{time: acc_time + time, input: new_input}}

          {status, :pipeline_skipped} ->
            {status, %{time: acc_time + 0, input: input}}

          {status, new_input} ->
            {status, %{time: acc_time + 0, input: new_input}}
        end
      end

      defp run_stage({type, name, opts}, input),
        do: run_stage({Pipeline, type, name, opts}, input)

      defp run_stage({module, :step, name, opts} = stage, input), do: Step.run(stage, input)
      defp run_stage({module, :tee, name, opts} = stage, input), do: Tee.run(stage, input)
      defp run_stage({module, :check, name, opts} = stage, input), do: Check.run(stage, input)
      defp run_stage({module, :link, name, opts} = stage, input), do: Link.run(stage, input)
      defp run_stage({module, :skip, name, opts} = stage, input), do: Skip.run(stage, input)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    default_instrumentation = Opus.Instrumentation.default_callback()

    quote do
      @doc false
      def stages, do: @opus_stages |> Enum.reverse()
      @opus_grouped_callbacks @opus_callbacks |> Enum.group_by(& &1.stage_id)
      def _opus_callbacks(), do: @opus_grouped_callbacks
      unquote(default_instrumentation)
    end
  end

  defmacro link(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      if unquote(name) != __MODULE__ do
        case Code.ensure_compiled(unquote(name)) do
          {:error, _} ->
            raise CompileError,
              file: __ENV__.file,
              line: __ENV__.line,
              description:
                to_string(:elixir_aliases.format_error({:unloaded_module, unquote(name)}))

          _ ->
            :ok
        end
      end

      if unquote(name) == __MODULE__ || :erlang.function_exported(unquote(name), :pipeline?, 0) do
        unquote(callbacks)

        options =
          Opus.Pipeline.Registration.normalize_opts(
            unquote(opts),
            unquote(stage_id),
            @opus_callbacks
          )

        @opus_stages {:link, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
      end
    end
  end

  defmacro step(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)

      options =
        Opus.Pipeline.Registration.normalize_opts(
          unquote(opts),
          unquote(stage_id),
          @opus_callbacks
        )

      @opus_stages {:step, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end

  defmacro tee(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)

      options =
        Opus.Pipeline.Registration.normalize_opts(
          unquote(opts),
          unquote(stage_id),
          @opus_callbacks
        )

      @opus_stages {:tee, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end

  defmacro check(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)

      options =
        Opus.Pipeline.Registration.normalize_opts(
          unquote(opts),
          unquote(stage_id),
          @opus_callbacks
        )

      @opus_stages {:check, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end

  defmacro skip(name, opts \\ []) do
    stage_id = :erlang.unique_integer([:positive])
    callbacks = Opus.Pipeline.Registration.maybe_define_callbacks(stage_id, name, opts)

    quote do
      unquote(callbacks)

      options =
        Opus.Pipeline.Registration.normalize_opts(
          unquote(opts),
          unquote(stage_id),
          @opus_callbacks
        )

      @opus_stages {:skip, unquote(name), Map.new(options ++ [stage_id: unquote(stage_id)])}
    end
  end
end
