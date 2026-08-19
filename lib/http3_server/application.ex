defmodule Http3Server.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    options = Application.fetch_env!(:http3_server, :options)

    webtransport_opts =
      %{
        ip: options[:ip],
        transport: :h3,
        port: options[:port],
        certfile: options[:certfile],
        keyfile: options[:keyfile],
        handler: Http3Server.StreamHandler,
        compat_mode: options[:compat_mode]
      }
      |> IO.inspect()

    children = [
      # {Registry, keys: :unique, name: Http3Server.PubSub},
      {Phoenix.PubSub, name: Http3Server.PubSub},
      # Starts a worker by calling: Http3Server.Worker.start_link(arg)
      # {Http3Server.Worker, arg}
      {Registry, name: AudioPhoneCallManager, keys: :unique},
      {Registry, name: VideoPhoneCallManager, keys: :unique},
      # Supervisor.child_spec(
      #   {Task, fn -> :webtransport.start_listener(:webtransport_server, webtransport_opts) end},
      #   restart: :permanent
      # )
      {Task, fn -> :webtransport.start_listener(:webtransport_server, webtransport_opts) end},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Http3Server.AudioPhoneCallManagerSupervisor},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Http3Server.VideoPhoneCallManagerSupervisor}
    ]

    # children = []

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Http3Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
