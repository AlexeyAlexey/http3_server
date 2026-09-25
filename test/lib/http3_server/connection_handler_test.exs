defmodule Http3Server.ConnectionHandlerTest do
  use ExUnit.Case, async: true

  import Http3Server.ConnectionSessionMock
  alias Http3Server.ConnectionHandler
  alias Http3Server.AuthToken

  describe "phone call" do
    test "successfully" do
      data = %{
        host: "local",
        room_id: "phone_call:123e4567-e89b-12d3-a456-426614174000",
        participant_id: 123,
        custom_params: %{
          "id" => "id",
          "from" => "local@123",
          "to" => "host1@1234",
          "direction" => "outcome",
          "stream_type" => "audio",
          "type" => "phone_call"
        }
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert {:continue, state} =
               mock_connection_session(path: "/", auth_token: auth_token)
               |> ConnectionHandler.handle_session()

      assert state ==
               data
               |> Map.take([:room_id, :participant_id, :custom_params])
    end

    test "auth token is required" do
      assert {:error, %{error: "auth token is required"}} =
               mock_connection_session(path: "/", auth_token: "")
               |> ConnectionHandler.handle_session()
    end
  end

  describe "conference" do
    test "successfully" do
      data = %{
        host: "local",
        room_id: "phone_call:123e4567-e89b-12d3-a456-426614174000",
        participant_id: 123,
        custom_params: %{
          "id" => "id",
          "conference_id" => "XXXXXXXXXX",
          "stream_type" => "audio",
          "type" => "phone_call"
        }
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert {:continue, state} =
               mock_connection_session(path: "/", auth_token: auth_token)
               |> ConnectionHandler.handle_session()

      assert state ==
               data
               |> Map.take([:room_id, :participant_id, :custom_params])
    end

    test "auth token is required" do
      assert {:error, %{error: "auth token is required"}} =
               mock_connection_session(path: "/", auth_token: "")
               |> ConnectionHandler.handle_session()
    end
  end
end
