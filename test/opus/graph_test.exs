defmodule Opus.GraphTest do
  use ExUnit.Case, async: false

  alias Opus.Graph, as: Subject

  setup do
    Path.wildcard("opus_opus_graph.*") |> File.rm()

    :ok
  end

  describe "generate/2 with the default config" do
    test "returns an :ok tuple" do
      message = "Graph file has been written to opus_opus_graph.png"

      assert {:ok, ^message} = Subject.generate(:opus)
    end

    test "generates the graph files (.png and .dot)" do
      Subject.generate(:opus)

      :timer.sleep(500)

      assert File.exists?("opus_opus_graph.dot")
      assert File.exists?("opus_opus_graph.png")
    end

    test "creates a node for each stage" do
      Subject.generate(:opus)

      :timer.sleep(500)

      {:ok, graph} = File.read("opus_opus_graph.dot")
      all_stages = length(Subject.stages()) + length(Opus.TestDummyPipeline.stages())

      assert_in_delta all_stages, length(Regex.scan(~r/class="opus-stage"/, graph)), 1
    end

    test "creates a node for each pipeline module" do
      Subject.generate(:opus)

      {:ok, app_modules} = :application.get_key(:opus, :modules)
      modules = for mod <- app_modules, function_exported?(mod, :pipeline?, 0), do: mod

      :timer.sleep(500)

      {:ok, graph} = File.read("opus_opus_graph.dot")

      assert_in_delta length(modules), length(Regex.scan(~r/class="opus-pipeline"/, graph)), 1

      for mod <- modules do
        assert is_list(Regex.run(~r/label="#{Regex.escape(inspect(mod))}"/, graph))
      end
    end

    test "generates edges for the stages" do
      Subject.generate(:opus)

      :timer.sleep(500)

      {:ok, graph} = File.read("opus_opus_graph.dot")

      assert length(Regex.scan(~r/node_\d*? -> node_\d*;/, graph)) >= length(Subject.stages())
    end
  end

  describe "generate/2 with a custom filename" do
    setup do
      filename = "some_amazing_app"
      Path.wildcard("#{filename}.*") |> File.rm()

      {:ok, %{filename: filename}}
    end

    test "when the filename is invalid, returns an :error tuple" do
      error = "Invalid filename for the compiled graph"

      assert {:error, %{error: ^error}} = Subject.generate(:opus, %{filename: 1111})
    end

    test "generates output files based on the given filename", %{filename: filename} do
      Subject.generate(:opus, %{filename: filename})

      :timer.sleep(500)

      assert File.exists?("#{filename}.dot")
      assert File.exists?("#{filename}.png")
    end
  end

  describe "generate/2 with a filetype" do
    test "when the filetype is invalid, returns an error tuple" do
      assert {:error, %{error: "Invalid output format"}} =
               Subject.generate(:opus, %{filetype: :exe})
    end

    test "when the filetype is a String, returns an error tuple" do
      assert {:error, %{error: "Invalid output format"}} =
               Subject.generate(:opus, %{filetype: "png"})
    end

    test "when the filetype is valid, builds output of that format" do
      assert {:ok, _} = Subject.generate(:opus, %{filetype: :svg})

      # Wait for the graphviz subprocess to produce output
      :timer.sleep(800)

      assert File.exists?("opus_opus_graph.svg")
    end
  end

  describe "generate/2 for an unknown app" do
    test "returns an :error tuple" do
      message = "Could not fetch Opus pipeline modules for the given app"

      assert {:error, %{error: ^message}} = Subject.generate(:uknown)
    end
  end

  describe "generate/2 for an application without pipelines" do
    test "returns an :error tuple" do
      message = "Could not find any Opus pipeline modules for the given application"

      assert {:error, %{error: ^message}} = Subject.generate(:kernel)
    end
  end
end
