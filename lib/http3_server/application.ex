defmodule Http3Server.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    options = Application.fetch_env!(:http3_server, :options)

    children = [
      # Starts a worker by calling: Http3Server.Worker.start_link(arg)
      # {Http3Server.Worker, arg}
      {Wtransport.Supervisor, options},
      PubSub
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Http3Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
