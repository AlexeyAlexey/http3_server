defmodule Http3Server.Auth.HostPublicKey do
  @host_public_keys %{
    "local" => System.fetch_env!("JWT_LOCAL_HOST_PUBLIC_KEY")
  }

  def fetch(endpoint) when is_binary(endpoint) do
    @host_public_keys[endpoint]
    |> case do
      nil -> {:error, "public key cannot be fetched from host"}
      key -> {:ok, key}
    end
  end
end
