defmodule Opus.TestDummyPipeline do
  use Opus.Pipeline

  require Opus.Graph

  link Opus.Graph
end
