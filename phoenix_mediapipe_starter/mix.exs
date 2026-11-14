defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {MyApp.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      # Oban for background job processing (video analysis via Python Port)
      {:oban, "~> 2.19"},
      # Ecto + PostgreSQL for persistence
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.17"},
      # JSON for port communication
      {:jason, "~> 1.4"},
      # DOM assertions for Phoenix.LiveViewTest
      {:lazy_html, ">= 0.1.0", only: :test},
      # Required for Oban plugins / timestamps
      {:timex, "~> 3.0"},
      # Embedding and serving static assets
      {:plug_cowboy, "~> 2.7"}
    ]
  end
end
