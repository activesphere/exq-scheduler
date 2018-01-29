defmodule ExqScheduler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exq_scheduler,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [:unmatched_returns, :race_conditions, :error_handling, :underspecs]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:logger, :timex, :redix, :crontab],
      mod: {ExqScheduler, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.1"},
      {:redix, ">= 0.0.0"},
      {:poison, "~> 3.1"},
      {:crontab, "~> 1.1"},
      {:exq, "~> 0.9.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
