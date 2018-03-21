defmodule Opus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :opus,
      version: "0.1.1",
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      name: "Opus",
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 0.8.10", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.18", only: :dev},
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end

  defp description, do: "Framework for creating pluggable business logic components"

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", ".formatter.exs"],
      maintainers: ["Dimitris Zorbas"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/zorbash/opus"}
    ]
  end
end
