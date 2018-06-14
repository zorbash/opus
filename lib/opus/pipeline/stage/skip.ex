defmodule Opus.Pipeline.Stage.Skip do
  @moduledoc ~S"""
  The skip stage is meant to halt the pipeline with no error if the given condition is true.
  This stage must be called with an `if` option, in order to decide if the pipeline is going to be
  halted or not.

  When the given conditional is `true`, the pipeline will return {:ok, :skipped} and all the following
  steps will be skipped.

  ```
  defmodule CreateUserPipeline do
    use Opus.Pipeline

    skip if: :user_exists?
    step :persist_user
  end
  ```

  In this example, if the `user_exists?` implementation returns `true`, then the next step `persist_user`
  is not going to be called. If `false` or any other value, then Opus will keep following to the next stages.
  """

  alias Opus.Pipeline.Stage

  @behaviour Stage

  def run({module, type, [if: func], opts}, input) do
    case Stage.maybe_run({module, type, nil, opts |> put_in([:if], func)}, input) do
      :pipeline_skipped -> {:halt, :skipped}
      _ -> {:cont, input}
    end
  end
end
