# Opus

[![Build Status](https://travis-ci.org/Zorbash/opus.svg?branch=master)](https://travis-ci.org/Zorbash/opus)
[![Package Version](https://img.shields.io/hexpm/v/opus.svg)](https://hex.pm/packages/opus)
[![Coverage Status](https://coveralls.io/repos/github/Zorbash/opus/badge.svg?branch=master)](https://coveralls.io/github/Zorbash/opus?branch=master)

A framework for pluggable business logic components.

![example-image](https://i.imgur.com/WwuyojJ.png)

## Installation

The package can be installed by adding `opus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:opus, "~> 0.6"}]
end
```

## Documentation

* [hexdocs](https://hexdocs.pm/opus)
* [wiki](https://github.com/Zorbash/opus/wiki)

## Conventions

* Each Opus pipeline module has a single entry point and returns tagged tuples
    `{:ok, value} | {:error, error}`
* A pipeline is a composition of stateless stages
* A stage returning `{:error, _}` halts the pipeline
* A stage may be skipped based on a condition function (`:if` option)
* Exceptions are converted to `{:error, error}` tuples by default
* An exception may be left to raise using the `:raise` option
* Each stage of the pipeline is instrumented. Metrics are captured
  automatically (but can be disabled).
* Errors are meaningful and predictable

## Usage

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  skip                    if: :greater_than_fifty?
  step  :add_one,         with: &(&1 + 1)
  check :even?,           with: &(rem(&1, 2) == 0), error_message: :expected_an_even
  tee   :publish_number,  if: &Publisher.publishable?/1, raise: [ExternalError]
  step  :double,          if: :lucky_number?
  step  :randomize,       with: &(&1 * :rand.uniform)
  link  JSONPipeline

  def double(n), do: n * 2
  def lucky_number?(n) when n in 42..1337, do: true
  def lucky_number?(_), do: false
  def greater_than_fifty?(n), do: n > 50
end

ArithmeticPipeline.call(41)
# {:ok, %{number: 84.13436750126804}}
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

  check :valid_params?, with: &match? %{email: email} when is_bitstring(email), &1
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

### Skip

This stage expects a `:if` option only, on which is expected to return a
boolean value. If `true`, then the pipeline halts and Opus returns
`{:ok, :skipped}`. If `false` or any other value is returned (including non-boolean),
then the next stage is called with no side effect.

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
* `:raise`: A list of exceptions to not rescue. Defaults to `false`
  which converts all exceptions to `{:error, %Opus.PipelineError{}}`
  values halting the pipeline.
* `:error_message`: A String or Atom to replace the original error when
  a stage fails.
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

  step :http_request, retry_times: 8, retry_backoff: fn -> lin_backoff(10, 2) |> cap(100) end

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

* `:before_stage`: Called before each stage
* `:stage_skipped`: Called when a conditional stage was skipped
* `:stage_completed`: Called after each stage

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

  def instrument(:stage_completed, %{stage: %{pipeline: ArithmeticPipeline}}, %{time: time}) do
    # publish the metrics to specific backend
  end

  def instrument(:stage_completed, _metadata, %{time: time}) do
    # publish the metrics to common backend
  end

  def instrument(:pipeline_completed, %{pipeline: ArithmeticPipeline}, %{input: input, time: total_time}) do
    # publish the metrics to specific backend
  end
end
```

## Module-Global Options

You may choose to provide some common options to all the stages of a pipeline.


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

## License

Copyright (c) 2018 Dimitris Zorbas, MIT License.
See [LICENSE.txt](https://github.com/zorbash/opus/blob/master/LICENSE.txt) for further details.

[hex-retry]: https://github.com/safwank/ElixirRetry/blob/master/lib/retry/delay_streams.ex
[hexdocs-graph]: https://hexdocs.pm/opus/Opus.Graph.html
[graphviz]: https://www.graphviz.org/
[dryrb-transaction]: https://dry-rb.org/gems/dry-transaction/
[trailblazer-operation]: http://trailblazer.to/gems/operation/2.0/
[medium-blogpost]: https://medium.com/quiqup-engineering/how-to-create-beautiful-pipelines-on-elixir-with-opus-f0b688de8994
