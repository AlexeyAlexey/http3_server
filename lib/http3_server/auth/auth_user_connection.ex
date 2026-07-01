defmodule Http3Server.AuthUserConnection do
  require Logger

  alias Http3Server.Auth.TrustedHost
  alias Http3Server.Auth.HostPublicKey

  def auth(auth_token) when is_binary(auth_token) do
    with {:ok, host} <- extract_host(auth_token),
         {:ok, public_key} <- get_public_key(host),
         {:ok, claims} <-
           Http3Server.AuthToken.verify_token(auth_token, public_key) do
      case claims do
        %{
          "from" => from,
          "to" => to,
          "type" => "phone_call" = type,
          "direction" => direction
        } = params ->
          {:ok,
           %{
             custom_params: Map.get(params, "custom_params", %{}) |> Map.take(["id"]),
             type: type,
             from: from,
             to: to,
             direction: direction
           }}

        %{
          "type" => "conference" = type,
          "conference_id" => conference_id
        } = params ->
          {:ok,
           %{
             custom_params: Map.get(params, "custom_params", %{}) |> Map.take(["id"]),
             type: type,
             conference_id: conference_id
           }}

        _ ->
          {:error, "auth token does not have required parameters"}
      end
    else
      {:error, :signature_error} ->
        {:error, "user cannot be authenticated"}

      {:error, "host is not trusted"} ->
        {:error, "host is not trusted"}

      {:error, "public key cannot be fetched from host"} ->
        {:error, "public key cannot be fetched from host"}

      error ->
        Logger.error(error)
        {:error, "unexpected error"}
    end
  end

  def auth(_) do
    {:error, "user cannot be authenticated. Auth token is not presented"}
  end

  defp extract_host(auth_token) when is_binary(auth_token) do
    [_head, body, _signature] = String.split(auth_token, ".")

    host =
      Base.decode64!(body, padding: false)
      |> Jason.decode!()
      |> Map.get("host")

    if host do
      {:ok, host}
    else
      {:ok, "host is not found in auth token"}
    end
  end

  defp get_public_key(host) when is_binary(host) do
    with {:ok, endpoint} <- TrustedHost.get_endpoint_by_name(host),
         {:ok, public_key} <- HostPublicKey.fetch(endpoint) do
      {:ok, public_key}
    end
  end
end
