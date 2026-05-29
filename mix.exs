defmodule Http3Server.MixProject do
  use Mix.Project

  def project do
    [
      app: :http3_server,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :observer, :wx, :runtime_tools],
      # extra_applications: [:logger, :observer, :runtime_tools],
      mod: {Http3Server.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:wtransport, git: "https://github.com/bugnano/wtransport-elixir.git"},
      {:pubsub, "~> 1.1"},
      # A JSON Web Token (JWT) Library.
      {:joken, "~> 2.6"},
      #  A blazing fast JSON parser and generator in pure Elixir.
      {:jason, "~> 1.4"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
