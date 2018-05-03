defmodule Opus.Graph do
  @available_filetypes [:svg, :png, :pdf]
  @defaults %{
    filetype: :png,
    docs_base_url: "",
    theme: %{
      penwidth: 2,
      stage_shape: "box",
      colors: %{
        border: %{
          pipeline: "#222222",
          conditional: "#F9E79F",
          normal: "#222222"
        },
        background: %{
          pipeline: "#DDDDDD",
          step: "#73C6B6",
          link: "#C39BD3",
          check: "#7FB3D5",
          tee: "#A6ACAF"
        },
        edges: %{
          link: "purple",
          normal: "black"
        }
      },
      style: %{
        normal: "filled",
        conditional: "filled, dashed"
      }
    }
  }

  @moduledoc """
  Generates a Graph with all the pipeline modules, their stages
  and their relationships when there are links.

  Make sure to have Graphviz installed before using this.

  Usage:

      Opus.Graph.generate(:awesome_app, %{filetype: :png, filename: "my_graph"})

  The above will create a `my_graph.png` graph image at the current working directory.

  Configuration:

  * `filetype`: The output format. Must be one of: `#{inspect(@available_filetypes)}`. Defaults to: #{
    inspect(@defaults[:filetype])
  }

  * `docs_base_url`: The prefix part of the documentation URLs set as hrefs for
  graph nodes.  Defaults to: `#{inspect(@defaults[:docs_base_url])}`

  * `theme`: A map of options on how the graph should be styled. Defaults to:

  ```
  #{inspect(@defaults[:theme], pretty: true)}
  ```
  """

  alias Graphvix.{Graph, Node, Edge}

  use Opus.Pipeline

  step :assign_config,
    with: fn %{app: app, config: config} = assigns ->
      put_in(
        assigns[:config],
        config || Application.get_env(app, :opus, %{})[:graph] || @defaults
      )
    end

  step :assign_modules,
    error_message: "Could not fetch Opus pipeline modules for the given app",
    with: fn %{app: app} = assigns ->
      {:ok, app_modules} = :application.get_key(app, :modules)
      modules = for mod <- app_modules, function_exported?(mod, :pipeline?, 0), do: mod

      put_in(assigns[:modules], modules)
    end

  check :pipelines_found?,
    error_message: "Could not find any Opus pipeline modules for the given application",
    with: &match?(%{modules: [_ | _]}, &1)

  check :filename_valid?,
    error_message: "Invalid filename for the compiled graph",
    with: &match?(%{config: %{filename: name}} when is_atom(name) or is_bitstring(name), &1),
    if: &match?(%{config: %{filename: _}}, &1)

  check :filetype_valid?,
    error_message: "Invalid output format",
    with: &match?(%{config: %{filetype: filetype}} when filetype in [:png, :svg, :pdf], &1),
    if: &match?(%{config: %{filetype: _}}, &1)

  step :normalize_filename,
    with: fn
      %{config: %{filename: filename}} = assigns ->
        put_in(assigns, [:config, :filename], :"#{filename}")

      %{app: app} = assigns ->
        put_in(assigns, [:config, :filename], :"#{app}_opus_graph")
    end

  step :initialize_graph,
    with: fn %{config: %{filename: filename}} = assigns ->
      Graph.new(filename)
      assigns
    end

  step :build_pipeline_nodes

  step :build_stage_nodes

  step :build_output,
    with: fn
      %{config: %{filetype: filetype}} = assigns ->
        Graph.compile(filetype)
        assigns

      assigns ->
        Graph.compile(:png)
        assigns
    end

  step :format_output,
    with: fn %{config: %{filename: filename, filetype: filetype}} ->
      "Graph file has been written to #{filename}.#{filetype}"
    end

  def generate(app, config \\ nil), do: call(%{app: app, config: config})

  @doc false
  def build_pipeline_nodes(%{modules: modules, config: config} = assigns) do
    nodes =
      for module <- modules do
        moduledoc = Code.get_docs(module, :moduledoc)

        {module,
         Node.new(
           label: inspect(module),
           penwidth: 2,
           href: module_href(config, module),
           class: "opus-pipeline",
           tooltip: tooltip(moduledoc),
           color: color(config, [:border, :pipeline]),
           fillcolor: color(config, [:background, :pipeline]),
           style: style(config, :normal)
         )}
      end

    put_in(assigns[:pipeline_nodes], nodes)
  end

  @doc false
  def build_stage_nodes(%{pipeline_nodes: pipeline_nodes, config: config} = assigns) do
    _ =
      for {module, root} <- pipeline_nodes do
        module.stages
        |> Enum.reduce(root, fn {type, name, opts}, {prev_id, _} ->
          {id, _node} =
            new_node =
            Node.new(
              label: "#{type}: #{inspect(name)}",
              penwidth: 2,
              class: "opus-stage",
              color: color(config, [:border, opts]),
              style: style(config, opts),
              fillcolor: color(config, [:background, type]),
              shape: from_config(config, [:theme, :stage_shape])
            )

          Edge.new(prev_id, id)

          case type do
            :link ->
              Edge.new(id, pipeline_nodes[name] |> elem(0), color: color(config, [:edges, :link]))

            _ ->
              :ok
          end

          new_node
        end)
      end

    assigns
  end

  defp color(config, [attr, %{if: _}]), do: color(config, [attr, :conditional])
  defp color(config, [attr, %{}]), do: color(config, [attr, :normal])
  defp color(config, list), do: from_config(config, [:theme, :colors | list])

  defp style(config, %{if: _}), do: from_config(config, [:theme, :style, :conditional])
  defp style(config, _type), do: from_config(config, [:theme, :style, :normal])

  defp from_config(config, attr), do: get_in(config, attr) || get_in(@defaults, attr)

  defp tooltip({_line, doc}) when is_bitstring(doc), do: html_entities(doc)
  defp tooltip(_), do: ""

  defp module_href(config, module), do: "#{Access.get(config, :base_url, "")}/#{module}.html"

  defp html_entities(string) do
    string
    |> String.graphemes()
    |> Enum.map(fn
      "'" -> "&apos;"
      "\"" -> "&quot;"
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      other -> other
    end)
    |> Enum.join()
  end
end
