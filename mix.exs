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
      {:redix, "~> 0.7.0"},
      {:redix_sentinel, "~> 0.6.0", only: :test},
      {:poison, "~> 3.1"},
      {:crontab, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.15.0", only: :dev},
      {:toxiproxy, "~> 0.3", only: :test}
    ]
  end
end
