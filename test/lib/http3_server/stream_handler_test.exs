defmodule Http3Server.StreamHandlerTest do
  use ExUnit.Case, async: true

  import Http3Server.StreamMock
  alias Http3Server.StreamHandler

  describe "phone call" do
    test "successfully" do
      state = %{
        from: "local@123",
        to: "host1@1234",
        direction: "outcome",
        stream_type: "video",
        type: "phone_call",
        custom_params: %{"id" => "id"}
      }

      assert mock_stream() |> StreamHandler.handle_stream(state) ==
               {:continue, state |> Map.take([:from, :to, :direction, :stream_type, :type])}
    end

    test "subscribed to call topic" do
      state = %{
        from: from = "local@123",
        to: to = "host1@1234",
        direction: "outcome",
        stream_type: stream_type = "video",
        type: "phone_call",
        custom_params: %{"id" => "id"}
      }

      topic = "#{stream_type}/phone_call/#{from}/#{to}"

      assert PubSub.subscribers(topic) == []

      assert mock_stream() |> StreamHandler.handle_stream(state)

      pid = self()

      assert PubSub.subscribers(topic) == [pid]
    end
  end

  describe "conference" do
    test "successfully" do
      state = %{
        conference_id: "XXXXXXXXXX",
        participant_id: 123,
        stream_type: "audio",
        type: "conference",
        custom_params: %{"id" => "id"}
      }

      assert mock_stream() |> StreamHandler.handle_stream(state) ==
               {:continue,
                state
                |> Map.take([
                  :conference_id,
                  :participant_id,
                  :stream_type,
                  :type,
                  :custom_params
                ])
                |> Map.put(:package_handler, %{buffer: <<>>, leftover_bytes: 0})}
    end

    test "subscribed to conference topic" do
      state = %{
        conference_id: conference_id = "XXXXXXXXXX",
        participant_id: 123,
        stream_type: stream_type = "audio",
        type: type = "conference",
        custom_params: %{"id" => "id"}
      }

      topic = "#{type}/#{stream_type}/#{conference_id}"

      assert PubSub.subscribers(topic) == []

      assert mock_stream() |> StreamHandler.handle_stream(state)

      pid = self()

      assert PubSub.subscribers(topic) == [pid]
    end
  end

  describe "conference handle data" do
    test "expand stream package with participant_id" do
      state = %{
        conference_id: conference_id = "XXXXXXXXXX",
        participant_id: participant_id = 123,
        stream_type: stream_type = "audio",
        type: type = "conference",
        custom_params: %{"id" => "id"},
        package_handler: %{buffer: <<>>, leftover_bytes: 0}
      }

      PubSub.subscribe(self(), "#{type}/#{stream_type}/#{conference_id}")

      data = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83>>

      assert {:continue, updated_state} = StreamHandler.handle_data(data, mock_stream(), state)

      assert updated_state ==
               state
               |> Map.take([
                 :conference_id,
                 :participant_id,
                 :stream_type,
                 :type,
                 :custom_params
               ])
               |> Map.put(:package_handler, %{buffer: <<77, 83>>, leftover_bytes: 0})

      assert_receive {:conference_stream, _pid,
                      <<77, 83, 69, 25::size(4)-unit(8), ^participant_id::size(4)-unit(8), 3::8,
                        "waiting_time_expired">>}
    end
  end
end
