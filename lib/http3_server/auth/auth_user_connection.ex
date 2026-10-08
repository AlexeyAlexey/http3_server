defmodule Http3Server.AuthUserConnection do
  require Logger

  alias Http3Server.Auth.TrustedHost
  alias Http3Server.Auth.HostPublicKey

  def auth(auth_token) when is_binary(auth_token) do
    with :ok <- check_if_auth_token_present(auth_token),
         {:ok, host} <- extract_host(auth_token),
         {:ok, public_key} <- get_public_key(host),
         {:ok, claims} <-
           Http3Server.AuthToken.verify_token(auth_token, public_key),
         {:ok, room_id} <- select_room_id(claims),
         {:ok, participant_id} <- select_participant_id(claims),
         {:ok, stream_type} <- select_stream_type(claims) do
      {:ok,
       %{
         room_id: room_id,
         participant_id: participant_id,
         stream_type: stream_type,
         custom_params: Map.get(claims, "custom_params", %{})
       }}
    else
      {:error, :signature_error} ->
        {:error, "user cannot be authenticated"}

      {:error, error}
      when error in [
             "host is not trusted",
             "public key cannot be fetched from host",
             "auth token is required",
             "room_id is reuired",
             "participant_id is reuired",
             "stream_type is reuired"
           ] ->
        {:error, error}

      error ->
        inspect(error)
        |> Logger.error()

        {:error, "unexpected error"}
    end
  end

  def auth(_) do
    {:error, "user cannot be authenticated. Auth token is not presented"}
  end

  defp check_if_auth_token_present(auth_token) when bit_size(auth_token) == 0 do
    {:error, "auth token is required"}
  end

  defp check_if_auth_token_present(_), do: :ok

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

  defp select_room_id(%{"room_id" => room_id}) when is_binary(room_id) do
    {:ok, room_id}
  end

  defp select_room_id(_), do: {:error, "room_id is reuired"}

  defp select_participant_id(%{"participant_id" => participant_id})
       when is_integer(participant_id) do
    {:ok, participant_id}
  end

  defp select_participant_id(_), do: {:error, "participant_id is reuired"}

  defp select_stream_type(%{"stream_type" => stream_type}) when is_binary(stream_type) do
    {:ok, stream_type}
  end

  defp select_stream_type(_), do: {:error, "stream_type is reuired"}
end
