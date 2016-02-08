defmodule GitHub.Ecto.Mixfile do
  use Mix.Project

  def project do
    [app: :github_ecto,
     version: "0.0.1",
     description: "Ecto adapter for GitHub API",
     package: package,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ecto, "~> 1.1"}, {:httpoison, "~> 0.8.0"}, {:poison, "~> 1.0"}, {:exvcr, "~> 0.7", only: :test}]
  end

  defp package do
    [
      maintainers: ["Wojtek Mach"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/wojtekmach/github_ecto"},
    ]
  end
end
