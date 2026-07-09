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
                ])}
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
end
