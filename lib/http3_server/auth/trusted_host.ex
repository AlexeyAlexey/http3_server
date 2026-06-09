defmodule Http3Server.Auth.TrustedHost do
  @trusted_hosts %{
    "local" => "local",
    "test" => "test"
  }

  def get_endpoint_by_name(name) when is_binary(name) do
    @trusted_hosts[name]
    |> case do
      nil -> {:error, "host is not trusted"}
      key -> {:ok, key}
    end
  end
end
