defmodule Opus.Mixfile do
  use Mix.Project

  def project do
    [app: :opus,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     description: description(),
     name: "Opus",
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.18", only: :dev}]
  end

  defp description, do: "Framework for creating pluggable business logic components"

  defp package do
    [
      files: ["lib", "mix.exs"],
      maintainers: ["Dimitris Zorbas"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/zorbash/opus"}
    ]
  end
end
