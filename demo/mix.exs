defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :exq, :exq_scheduler]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exq, "~> 0.13.3"},
      {:jason, "~> 1.1"},
      {:exq_scheduler, path: "../"}
    ]
  end
end
