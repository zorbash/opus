# Opus

[![Build Status](https://github.com/zorbash/opus/workflows/tests/badge.svg)](https://github.com/zorbash/opus/actions)
[![Package Version](https://img.shields.io/hexpm/v/opus.svg)](https://hex.pm/packages/opus)
[![Coverage Status](https://coveralls.io/repos/github/zorbash/opus/badge.svg?branch=master)](https://coveralls.io/github/zorbash/opus?branch=master)

[![Livebook badge](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fhexdocs.pm%2Fopus%2Ftutorial.livemd)

A framework for pluggable business logic components.

![example-image](https://i.imgur.com/WwuyojJ.png)

## Installation

The package can be installed by adding `opus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:opus, "~> 0.8"}]
end
```

## Documentation

* [hexdocs](https://hexdocs.pm/opus)
* [wiki](https://github.com/zorbash/opus/wiki)
* [tutorial](https://hexdocs.pm/opus/tutorial.html)

## Conventions

* Each Opus pipeline module has a single entry point and returns tagged tuples
    `{:ok, value} | {:error, error}`
* A pipeline is a composition of stateless stages
* A stage returning `{:error, _}` halts the pipeline
* A stage may be skipped based on a condition function (`:if` and `:unless` options)
* Exceptions are converted to `{:error, error}` tuples by default
* An exception may be left to raise using the `:raise` option
* Each stage of the pipeline is instrumented. Metrics are captured
  automatically (but can be disabled).
* Errors are meaningful and predictable

## Usage

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  step  :add_one,         with: &(&1 + 1)
  check :even?,           with: &(rem(&1, 2) == 0), error_message: :expected_an_even
  tee   :publish_number,  if: &Publisher.publishable?/1, raise: [ExternalError]
  step  :double,          if: :lucky_number?
  step  :divide,          unless: :lucky_number?
  step  :randomize,       with: &(&1 * :rand.uniform)
  link  JSONPipeline

  def double(n), do: n * 2
  def divide(n), do: n / 2
  def lucky_number?(n) when n in 42..1337, do: true
  def lucky_number?(_), do: false
end

ArithmeticPipeline.call(41)
# {:ok, 84.13436750126804}
```

Read this [blogpost][medium-blogpost] to get started.

## Pipeline

The core aspect of this library is defining pipeline modules. As in the
example above you need to add `use Opus.Pipeline` to turn a module into
a pipeline. A pipeline module is a composition of stages executed in
sequence.

## Stages

There are a few different types of stages for different use-cases.
All stage functions, expect a single argument which is provided either
from initial `call/1` of the pipeline module or the return value of the
previous stage.

An error value is either `:error` or `{:error, any}` and anything else
is considered a success value.

### Step

This stage processes the input value and with a success value the next
stage is called with that value. With an error value the pipeline is
halted and an `{:error, any}` is returned.

### Check

This stage is intended for validations.

This stage calls the stage function and unless it returns `true` it
halts the pipeline.

Example:

```elixir
defmodule CreateUserPipeline do
  use Opus.Pipeline

  check :valid_params?, with: &match?(%{email: email} when is_bitstring(email), &1)
  # other stages to actually create the user
end
```

### Tee

This stage is intended for side effects, such as a notification or a
call to an external system where the return value is not meaningful.
It never halts the pipeline.

### Link

This stage is to link with another Opus.Pipeline module. It calls
`call/1` for the provided module. If the module is not an
`Opus.Pipeline` it is ignored.

#### Skip

The `skip` macro can be used for linked pipelines.
A linked pipeline may act as a true bypass, based on a condition,
expressed as either `:if` or `:unless`. When skipped, none of the stages
are executed and it returns the input, to be used by any next stages of
the caller pipeline. A very common use-case is illustrated in the following example:


```elixir
defmodule RetrieveCustomerInformation do
  use Opus.Pipeline

  check :valid_query?
  link FetchFromCache,    if: :cacheable?
  link FetchFromDatabase, if: :db_backed?
  step :serialize
end
```

With `skip` it can be written as:

```elixir
defmodule RetrieveCustomerInformation do
  use Opus.Pipeline

  check :valid_query?
  link FetchFromCache
  link FetchFromDatabase
  step :serialize
end
```

A linked pipeline becomes:

```elixir
defmodule FetchFromCache do
  use Opus.Pipeline

  skip :assert_suitable, if: :cacheable?
  step :retrieve_from_cache
end
```

### Available options

The behaviour of each stage can be configured with any of the available
options:

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

### Retries

```elixir
defmodule ExternalApiPipeline do
  use Opus.Pipeline

  step :http_request, retry_times: 8, retry_backoff: fn -> linear_backoff(10, 30) |> cap(100) end

  def http_request(_input) do
    # code for the actual request
  end
end
```

The above module, will retry be retried up to 8 times, each time
applying a delay from the next value of the retry_backoff function, which returns a
Stream.

All the functions from the [:retry][hex-retry] package will be available to be used in `retry_backoff`.

## Stage Filtering

You can select the stages of a pipeline to run using `call/2` with the `:except` and `:only` options.

Example:

```elixir
# Runs only the stage with the :validate_params name
CreateUserPipeline.call(params, only: [:validate_params]

# Runs all the stages except the selected ones
CreateUserPipeline.call(params, except: :send_notification)
```

## Instrumentation

Instrumentation hooks which can be defined:

* `:pipeline_started`: Called before a pipeline module is called
* `:before_stage`: Called before each stage
* `:stage_skipped`: Called when a conditional stage was skipped
* `:stage_completed`: Called after each stage
* `:pipeline_completed`: Called after pipeline module has returned

You can disable all instrumentation callbacks for a stage using `instrument?: false`.

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  step :double, instrument?: false
end
```

You can define module specific instrumentation callbacks using:

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  step :double, with: &(&1 * 2)
  step :triple, with: &(&1 * 3)

  instrument :before_stage, fn %{input: input} ->
    IO.inspect input
  end

  # Will be called only for the matching stage
  instrument :stage_completed, %{stage: %{name: :triple}}, fn %{time: time} ->
    # send to the monitoring tool of your choice
  end
end
```

You can define a default instrumentation module for all your pipelines
by adding in your `config/*.exs`:

```elixir
config :opus, :instrumentation, YourModule

# but you may choose to provide a list of modules
config :opus, :instrumentation, [YourModuleA, YourModuleB]
```

An instrumentation module has to export `instrument/3` functions like:

```elixir
defmodule CustomInstrumentation do
  def instrument(:pipeline_started, %{pipeline: ArithmeticPipeline}, %{input: input}) do
    # publish the metrics to specific backend
  end

  def instrument(:before_stage, %{stage: %{pipeline: pipeline}}, %{input: input}) do
    # publish the metrics to specific backend
  end

  def instrument(:stage_completed, %{stage: %{pipeline: ArithmeticPipeline}}, %{time: time}) do
    # publish the metrics to specific backend
  end

  def instrument(:pipeline_completed, %{pipeline: ArithmeticPipeline}, %{result: result, time: total_time}) do
    # publish the metrics to specific backend
  end

  def instrument(_, _, _), do: nil
end
```

### Telemetry

Opus includes an instrumentation module which emits events using the `:telemetry` library.  
To enable it, change your `config/config.exs` with:

```elixir
config :opus, :instrumentation, [Opus.Telemetry]
```

Browse the available events [here][opus-telemetry].

For instructions to integrate Opus Telemetry metrics in your Phoenix
application, read this [post][post-opus-telemetry].

## Module-Global Options

You may choose to provide some common options to all the stages of a pipeline.

* `:raise`: A list of exceptions to not rescue. When set to `true`, Opus
    does not handle any exceptions. Defaults to `false` which converts all exceptions
    to `{:error, %Opus.PipelineError{}}` values halting the pipeline.
* `:instrument?`: A boolean which defaults to `true`. Set to `false` to
  skip instrumentation for a module.

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline, instrument?: false, raise: true
  # The pipeline opts will disable instrumentation for this module
  # and will not rescue exceptions from any of the stages

  step :double, with: &(&1 * 2)
  step :triple, with: &(&1 * 3)
end
```

## Graph

You may visualise your pipelines using `Opus.Graph`:

```elixir
Opus.Graph.generate(:your_app)
# => {:ok, "Graph file has been written to your_app_opus_graph.png"}
```

:exclamation: This feature requires the [`opus_graph`][opus_graph] package to be installed, add it in your
mix.exs.

```elixir
defp deps do
  {:opus_graph, "~> 0.1", only: [:dev]}
end
```

### Setup

First make sure to add `graphvix` to your dependencies:

```elixir
# in mix.exs

defp deps do
  [
    {:opus, "~> 0.5"},
    {:graphvix, "~> 0.5", only: [:dev]}
  ]
end

```

This feature uses [graphviz][graphviz], so make sure to have it
installed. To install it:

```shell
# MacOS

brew install graphviz
```

```shell
# Debian / Ubuntu

apt-get install graphviz
```

`Opus.Graph` is in fact a pipeline and its visualisation is:

![graph-png](https://i.imgur.com/41kHjZL.png)

You can customise the visualisation:

```elixir
Opus.Graph.generate(:your_app, %{filetype: :svg})
# => {:ok, "Graph file has been written to your_app_opus_graph.svg"}
```

Read the available visualisation options [here][hexdocs-graph].

## Influences

* [dry.rb - transaction][dryrb-transaction]
* [trailblazer - operation][trailblazer-operation]

## Press

* [Quiqup Engineering - How to Create Beautify Pipelines with Opus](https://medium.com/quiqup-engineering/how-to-create-beautiful-pipelines-on-elixir-with-opus-f0b688de8994)
* [Pagerduty - How I Centralized our Scattered Business Logic Into One Clear Pipeline for our Elixir Webhook Service](https://www.pagerduty.com/eng/elixir-webhook-service/)
* [A Slack bookmarking application in Elixir with Opus](https://zorbash.com/post/slack-bookmarks-collaboration-elixir/)
* [Opus Telemetry](https://zorbash.com/post/phoenix-telemetry/)

Using Opus in your company / project?  
Let us know by submitting an issue describing how you use it.

## License

Copyright (c) 2018 Dimitris Zorbas, MIT License.
See [LICENSE.txt](https://github.com/zorbash/opus/blob/master/LICENSE.txt) for further details.

[hex-retry]: https://github.com/safwank/ElixirRetry/blob/master/lib/retry/delay_streams.ex
[hexdocs-graph]: https://hexdocs.pm/opus/Opus.Graph.html
[graphviz]: https://www.graphviz.org/
[dryrb-transaction]: https://dry-rb.org/gems/dry-transaction/
[trailblazer-operation]: http://trailblazer.to/gems/operation/2.0/
[medium-blogpost]: https://medium.com/quiqup-engineering/how-to-create-beautiful-pipelines-on-elixir-with-opus-f0b688de8994
[opus_graph]: https://github.com/zorbash/opus_graph
[opus-telemetry]: https://hexdocs.pm/opus/Opus.Telemetry.html
[post-opus-telemetry]: https://zorbash.com/post/phoenix-telemetry/
