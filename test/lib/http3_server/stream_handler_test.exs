defmodule Http3Server.StreamHandlerTest do
  use ExUnit.Case, async: true

  import Http3Server.StreamMock
  alias Http3Server.StreamHandler

  describe "phone call" do
    test "successfully" do
      state = %{
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

      assert mock_stream() |> StreamHandler.handle_stream(state) ==
               {:continue,
                state
                |> Map.take([:room_id, :participant_id, :custom_params])
                |> Map.put(:package_handler, %{buffer: <<>>, leftover_bytes: 0})}
    end

    test "subscribed to call topic" do
      state = %{
        room_id: room_id = "phone_call:123e4567-e89b-12d3-a456-426614174000",
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

      topic = room_id

      assert PubSub.subscribers(topic) == []

      assert mock_stream() |> StreamHandler.handle_stream(state)

      pid = self()

      assert PubSub.subscribers(topic) == [pid]
    end
  end

  describe "conference" do
    test "successfully" do
      state = %{
        room_id: "conference:123e4567-e89b-12d3-a456-426614174000",
        participant_id: 123,
        custom_params: %{
          "id" => "id",
          "conference_id" => "XXXXXXXXXX",
          "stream_type" => "audio",
          "type" => "phone_call"
        }
      }

      assert mock_stream() |> StreamHandler.handle_stream(state) ==
               {:continue,
                state
                |> Map.take([
                  :room_id,
                  :participant_id,
                  :custom_params
                ])
                |> Map.put(:package_handler, %{buffer: <<>>, leftover_bytes: 0})}
    end

    test "subscribed to conference topic" do
      state = %{
        room_id: room_id = "conference:123e4567-e89b-12d3-a456-426614174000",
        participant_id: 123,
        custom_params: %{
          "id" => "id",
          "conference_id" => "XXXXXXXXXX",
          "stream_type" => "audio",
          "type" => "phone_call"
        }
      }

      topic = room_id

      assert PubSub.subscribers(topic) == []

      assert mock_stream() |> StreamHandler.handle_stream(state)

      pid = self()

      assert PubSub.subscribers(topic) == [pid]
    end
  end

  describe "conference handle data" do
    test "expand stream package with participant_id" do
      state = %{
        room_id: room_id = "conference:123e4567-e89b-12d3-a456-426614174000",
        participant_id: participant_id = 123,
        custom_params: %{
          "id" => "id",
          "conference_id" => "XXXXXXXXXX",
          "stream_type" => "audio",
          "type" => "phone_call"
        },
        package_handler: %{buffer: <<>>, leftover_bytes: 0}
      }

      PubSub.subscribe(self(), room_id)

      data = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83>>

      assert {:continue, updated_state} = StreamHandler.handle_data(data, mock_stream(), state)

      assert updated_state ==
               state
               |> Map.take([
                 :room_id,
                 :participant_id,
                 :custom_params
               ])
               |> Map.put(:package_handler, %{buffer: <<77, 83>>, leftover_bytes: 0})

      assert_receive {:room_stream, _pid,
                      <<77, 83, 69, 25::size(4)-unit(8), ^participant_id::size(4)-unit(8), 3::8,
                        "waiting_time_expired">>}
    end
  end
end
