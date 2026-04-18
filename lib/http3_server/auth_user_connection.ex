defmodule Http3Server.AuthUserConnection do
  require Logger
  alias Wtransport.Session

  def auth(%Session{path: "/"}) do
    {:error, "user cannot be authenticated"}
  end

  def auth(%Session{path: path}) when is_binary(path) do
    uri = URI.parse(path)
    params = URI.decode_query(uri.query)
    Logger.info(IO.inspect(params))

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

      [room_id, user_id] =
        case claims do
          %{"room_id" => "params", "participant_id" => "params"} ->
            user_id =
              if is_integer(params["participant_id"]),
                do: params["participant_id"],
                else: String.to_integer(params["participant_id"])

            [params["room_id"], user_id]

          _ ->
            [claims["room_id"], claims["participant_id"]]
        end

      {:ok,
       %{
         user_id: user_id,
         room_id: room_id,
         stream_type: stream_type
       }}
    else
      {:error, :signature_error} ->
        {:error, "user cannot be authenticated"}
    end
  end

  def auth(_) do
    {:error, "user cannot be authenticated"}
  end
end
