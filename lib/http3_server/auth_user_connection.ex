defmodule Http3Server.AuthUserConnection do
  require Logger
  alias Wtransport.Session

  def auth(%Session{path: "/"}) do
    {:error, "user cannot be authenticated"}
  end

  def auth(%Session{path: path}) when is_binary(path) do
    uri = URI.parse(path)
    params = URI.decode_query(uri.query)

    Logger.info("params: #{inspect(params)}")

    with {:ok, claims} <- Http3Server.AuthToken.verify_and_validate(params["auth_token"]) do
      stream_type =
        cond do
          String.contains?(path, "video") ->
            "video"

          String.contains?(path, "audio") ->
            "audio"

          true ->
            nil
        end

      case claims do
        %{"room_id" => "params", "participant_id" => "params"} ->
          user_id =
            if is_integer(params["participant_id"]),
              do: params["participant_id"],
              else: String.to_integer(params["participant_id"])

          {:ok,
           %{
             user_id: user_id,
             room_id: params["room_id"],
             stream_type: stream_type
           }}

        %{"from" => from, "to" => to, "type" => type, "direction" => direction} ->
          {:ok,
           %{
             type: type,
             from: from,
             to: to,
             direction: direction,
             stream_type: stream_type
           }}

        _ ->
          [claims["room_id"], claims["participant_id"]]
      end
    else
      {:error, :signature_error} ->
        {:error, "user cannot be authenticated"}
    end
  end

  def auth(_) do
    {:error, "user cannot be authenticated"}
  end
end
