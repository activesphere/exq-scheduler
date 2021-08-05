defmodule ExqScheduler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exq_scheduler,
      version: "0.7.2",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Cron like job scheduler for Exq",
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [:unmatched_returns, :race_conditions, :error_handling, :underspecs]
      ],
      xref: [exclude: [Jason]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExqScheduler, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tzdata, "~> 0.5.20"},
      {:timex, ">= 3.1.0 and < 3.4.0"},
      {:redix, "~> 0.7"},
      {:redix_sentinel, "~> 0.6.0", only: :test},
      {:poison, "~> 3.1", optional: true},
      {:crontab, "~> 1.1"},
      {:elixir_uuid, "~> 1.2"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:toxiproxy, "~> 0.3", only: :test}
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/activesphere/exq-scheduler"},
      maintainers: ["ananthakumaran@gmail.com", "akashh246@gmail.com"]
    }
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
