defmodule Opus.Pipeline.Stage.Check do
  @moduledoc ~S"""
  The check stage is intended to assert its input fulfils certain criteria
  otherwise the pipeline is halted.

  Its implementation must return `true` to proceed running any next steps.
  When the check fails, an Atom error message is provided by default to allow for pattern-matching.

  ```
  defmodule CreateUserPipeline do
    use Opus.Pipeline

    check :valid_params?, with: &UserValidator.validate/1
  end
  ```

  When the `:valid_params?` check fails, the return value of the pipeline will be:
  `{:error, %Opus.PipelineError{error: :failed_check_valid_params?}}`
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run({module, type, name, opts} = stage, input) do
    case Stage.maybe_run(stage, input) do
      ret when ret in [true, :stage_skipped] ->
        {:cont, input}

      _error ->
        opts = update_in(opts[:error_message], &(&1 || :"failed_check_#{name}"))
        Stage.handle_run(:error, %{stage: {module, type, name, opts}, input: input})
    end
  end
end
