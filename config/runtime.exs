import Config

if System.fetch_env!("MIX_ENV") == "dev" do
  config :http3_server, :options,
    host: System.fetch_env!("HOST"),
    port: System.fetch_env!("PORT") |> String.to_integer(),
    certfile: System.fetch_env!("SSL_CERT_PATH"),
    keyfile: System.fetch_env!("SSL_KEY_PATH"),
    connection_handler: Http3Server.ConnectionHandler,
    stream_handler: Http3Server.StreamHandler,
    # log_network_data: true,
    level: :all,
    level: :error,
    default_formatter: [
      format: "$time ( $metadata) [$level] $message\n",
      metadata: [:mfa, :line]
    ]

  # config :joken, default_signer: System.fetch_env!("JWT_SECRET")
else
  config :http3_server, :options,
    host: System.fetch_env!("HOST"),
    port: System.fetch_env!("PORT") |> String.to_integer(),
    certfile: System.fetch_env!("SSL_CERT_PATH"),
    keyfile: System.fetch_env!("SSL_KEY_PATH"),
    connection_handler: Http3Server.ConnectionHandler,
    stream_handler: Http3Server.StreamHandler,
    # log_network_data: true,
    # config :logger,
    level: :error,
    default_formatter: [
      format: "$time ( $metadata) [$level] $message\n",
      metadata: [:mfa, :line]
    ]

  # config :joken, default_signer: System.fetch_env!("JWT_SECRET")

  config :logger, :default_formatter,
    format: "[$level] $metadata $message ",
    metadata: [:error_code, :file, :line]
end
