defmodule Opus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :opus,
      version: "0.6.0",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
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
      ],
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_url: "https://github.com/Zorbash/opus"
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:retry, "~> 0.8"},
      {:graphvix, "~> 0.5"},
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
