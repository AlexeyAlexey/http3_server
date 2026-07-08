defmodule Http3Server.ConnectionHandlerTest do
  use ExUnit.Case, async: true

  import Http3Server.ConnectionSessionMock
  alias Http3Server.ConnectionHandler
  alias Http3Server.AuthToken

  describe "phone call" do
    test "successfully" do
      data = %{
        host: "local",
        from: "local@123",
        to: "host1@1234",
        direction: "outcome",
        stream_type: "video",
        type: "phone_call",
        custom_params: %{"id" => "id"}
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
               |> Map.take([:from, :to, :direction, :type, :custom_params, :stream_type])
    end

    test "auth token is required" do
      assert {:error, %{error: "auth token is required"}} =
               mock_connection_session(path: "/", auth_token: "")
               |> ConnectionHandler.handle_session()
    end
  end
end
