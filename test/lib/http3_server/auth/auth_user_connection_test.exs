defmodule Http3Server.AuthUserConnectionTest do
  use ExUnit.Case

  alias Http3Server.{AuthUserConnection, AuthToken}

  test "connection request without required parameters" do
    assert {:error, "user cannot be authenticated. Auth token is not presented"} =
             AuthUserConnection.auth(nil)
  end

  describe "one to one call" do
    test "successfully auth" do
      data = %{
        host: "local",
        from: "local@123",
        to: "host1@1234",
        direction: "outcome",
        stream_type: "audio",
        type: "phone_call",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) == {:ok, data |> Map.delete(:host)}
    end

    test "host is not trusted" do
      data = %{
        host: "global",
        from: "local@123",
        to: "host1@1234",
        direction: "outcome",
        stream_type: "audio",
        type: "phone_call",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) == {:error, "host is not trusted"}
    end

    test "public key cannot be fetched from host" do
      data = %{
        host: "test",
        from: "local@123",
        to: "host1@1234",
        direction: "outcome",
        stream_type: "audio",
        type: "phone_call",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) ==
               {:error, "public key cannot be fetched from host"}
    end
  end

  describe "conference" do
    test "successfully auth" do
      data = %{
        host: "local",
        conference_id: "XXXXXXXXXX",
        participant_id: 123,
        stream_type: "audio",
        type: "conference",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) == {:ok, data |> Map.delete(:host)}
    end

    test "conference_id is required parameter" do
      data = %{
        host: "local",
        # conference_id: "XXXXXXXXXX",
        participant_id: 123,
        stream_type: "audio",
        type: "conference",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) ==
               {:error, "auth token does not have required parameters"}
    end

    test "participant_id is required parameter" do
      data = %{
        host: "local",
        conference_id: "XXXXXXXXXX",
        # participant_id: 123,
        type: "conference",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) ==
               {:error, "auth token does not have required parameters"}
    end

    test "participant_id is not integer" do
      data = %{
        host: "local",
        conference_id: "XXXXXXXXXX",
        participant_id: "123",
        type: "conference",
        custom_params: %{"id" => "id"}
      }

      {:ok, auth_token} =
        AuthToken.generate_token(
          data,
          System.fetch_env!("JWT_LOCAL_HOST_SECRET_KEY")
        )

      assert AuthUserConnection.auth(auth_token) ==
               {:error, "auth token does not have required parameters"}
    end
  end
end
