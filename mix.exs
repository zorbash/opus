defmodule Opus.Mixfile do
  use Mix.Project

  @source_url "https://github.com/zorbash/opus"

  def project do
    [
      app: :opus,
      version: "0.8.4",
      elixir: "~> 1.6",
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
      dialyzer: [plt_add_apps: [:telemetry]],
      docs: [
        homepage_url: @source_url,
        source_url: @source_url,
        extras: ["CHANGELOG", "README.md", "priv/tutorial.livemd"],
        formatters: ["html"],
        main: "readme"
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
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test}
    ]
  end

  defp description, do: "Framework for creating pluggable business logic components"

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.txt", ".formatter.exs"],
      maintainers: ["Dimitris Zorbas"],
      licenses: ["MIT"],
      links: %{
        github: "https://github.com/zorbash/opus",
        changelog: "https://github.com/zorbash/opus/master/CHANGELOG"
      }
    ]
  end
end
