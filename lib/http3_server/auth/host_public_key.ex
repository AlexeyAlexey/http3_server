defmodule Http3Server.Auth.HostPublicKey do
  # @host_public_keys %{
  #   "local" => "JWT_LOCAL_HOST_PUBLIC_KEY"
  # }
  # TODO implement fetch public key from known host to verify JWT to connect. (z key)

  def fetch("local") do
    local_host_public_key()
    |> case do
      nil -> {:error, "public key cannot be fetched from host"}
      key -> {:ok, key}
    end
  end

  def fetch(_), do: {:error, "public key cannot be fetched from host"}

  defp local_host_public_key, do: System.fetch_env!("JWT_LOCAL_HOST_PUBLIC_KEY")
end
