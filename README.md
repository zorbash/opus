# Opus

[![Build Status](https://travis-ci.org/Zorbash/opus.svg?branch=master)](https://travis-ci.org/Zorbash/opus)
[![Package Version](https://img.shields.io/hexpm/v/opus.svg)](https://hex.pm/packages/opus)

A framework for pluggable business logic components.

![example-image](https://i.imgur.com/WwuyojJ.png)

## Installation

The package can be installed by adding `opus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:opus, "~> 0.1"}]
end
```

## Features

* Each Opus pipeline module has a single entry point and returns tagged tuples
    `{:ok, value} | {:error, error}`
* A pipeline is a composition of stateless stages
* A stage returning `{:error, _}` halts the pipeline
* A stage may be skipped based on a condition function (`:if` option)
* Exceptions are converted to {:error, error} tuples by default
* An exception may be left to raise using the `:raise` option
* Each stage of the timeline is instrumented. Metrics are captured
  automatically (but can be disabled).
* Errors are meaningful and predictable

## Usage

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  step  :add_one,         with: &(&1 + 1)
  check :even?,           with: &(rem(&1, 2) == 0)
  tee   :publish_number,  if: &Publisher.publishable?/1, raise: [ExternalError]
  step  :double,          if: :lucky_number?
  step  :randomize,       with: &(&1 * :rand.uniform)
  link  JSONPipeline

  def double(n), do: n * 2
  def lucky_number?(n) when n in 42..1337, do: true
  def lucky_number?(_), do: false
end

ArithmeticPipeline.call(41)
# {:ok, %{number: 84.13436750126804}}
```

## Instrumentation

Instrumentation hooks can be defined

* `:before_stage`: Called before each stage
* `:stage_skipped`: Called a conditional stage was skipped
* `:stage_completed`: Called after each stage

You can disable all instrumentation callbacks for a stage using `instrument: false`.

```elixir
defmodule ArithmeticPipeline do
  use Opus.Pipeline

  step :double, instrument: false
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
  def instrument(:stage_completed, %{stage: %{pipeline: ArithmeticPipeline}}, %{time: time}) do
    # publish the metrics to specific backend
  end

  def instrument(:stage_completed, _metadata, %{time: time}) do
    # publish the metrics to common backend
  end
end
```

## License

Copyright (c) 2018 Dimitris Zorbas, MIT License.
See [LICENSE.txt](https://github.com/zorbash/opus/blob/master/LICENSE.txt) for further details.
