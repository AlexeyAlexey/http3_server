defmodule Http3Server.PhoneCallManager do
  alias Http3Server.VideoPhoneCallManager
  alias Http3Server.AudioPhoneCallManager

  def state(call_id, :audio) do
    AudioPhoneCallManager.state(call_id)
  end

  def state(call_id, :video) do
    VideoPhoneCallManager.state(call_id)
  end

  def connect(
        pid,
        %{
          custom_params: custom_params,
          direction: direction,
          stream_type: stream_type = "audio",
          type: "phone_call",
          from: from,
          to: to
        }
      )
      when is_pid(pid) do
    with {:ok, res} <-
           AudioPhoneCallManager.connect(
             pid,
             %{
               custom_params: custom_params,
               direction: direction,
               type: "phone_call",
               from: from,
               to: to
             }
           ),
         :ok <- subscribe(pid, stream_type: stream_type, from: from, to: to) do
      {:ok, res}
    else
      error ->
        error
    end
  end

  def connect(
        pid,
        %{
          custom_params: custom_params,
          direction: direction,
          stream_type: stream_type = "video",
          type: "phone_call",
          from: from,
          to: to
        }
      )
      when is_pid(pid) do
    with {:ok, res} <-
           VideoPhoneCallManager.connect(pid, %{
             custom_params: custom_params,
             direction: direction,
             type: "phone_call",
             from: from,
             to: to
           }),
         :ok <- subscribe(pid, stream_type: stream_type, from: from, to: to) do
      {:ok, res}
    else
      error ->
        error
    end
  end

  def subscribe(pid, stream_type: stream_type, from: from, to: to) when is_pid(pid) do
    stream_topic = stream_topic(stream_type: stream_type, from: from, to: to)

    PubSub.subscribe(pid, stream_topic)
  end

  def user_ended_call(%{
        direction: direction,
        type: "phone_call",
        from: from,
        to: to,
        reason: reason,
        stream_type: _
      }) do
    AudioPhoneCallManager.end_call(%{
      direction: direction,
      type: "phone_call",
      from: from,
      to: to,
      reason: reason
    })

    VideoPhoneCallManager.end_call(%{
      direction: direction,
      type: "phone_call",
      from: from,
      to: to,
      reason: reason
    })
  end

  def send_data_to_stream(stream_type: stream_type, from: from, to: to, data: data)
      when is_binary(data) do
    stream_topic(
      stream_type: stream_type,
      from: from,
      to: to
    )
    |> PubSub.publish({:phone_call_stream, self(), data})
  end

  def send_data_to_video_stream(from: from, to: to, data: data) when is_binary(data) do
    send_data_to_stream(stream_type: "video", from: from, to: to, data: data)
  end

  def send_data_to_audio_stream(from: from, to: to, data: data) when is_binary(data) do
    send_data_to_stream(stream_type: "audio", from: from, to: to, data: data)
  end

  def trigger_video_stream_callback(callback,
        from: from,
        to: to,
        message: message
      ) do
    video_stream_topic(
      from: from,
      to: to
    )
    |> PubSub.publish({callback, message})
  end

  def trigger_video_stream_callback(callback,
        from: from,
        to: to
      ) do
    video_stream_topic(
      from: from,
      to: to
    )
    |> PubSub.publish(callback)
  end

  def trigger_audio_stream_callback(callback, from: from, to: to, message: message) do
    audio_stream_topic(
      from: from,
      to: to
    )
    |> PubSub.publish({callback, message})
  end

  def trigger_audio_stream_callback(callback, from: from, to: to) do
    audio_stream_topic(
      from: from,
      to: to
    )
    |> PubSub.publish(callback)
  end

  def call_id(
        from: from,
        to: to
      ) do
    "phone_call/#{from}/#{to}"
  end

  def audio_stream_topic(from: from, to: to),
    do: stream_topic(stream_type: "audio", from: from, to: to)

  def video_stream_topic(from: from, to: to),
    do: stream_topic(stream_type: "video", from: from, to: to)

  # TODO replace topic by internal implementation. Parameters from jwt should not be used directly
  # to build topic ?
  def stream_topic(stream_type: stream_type, from: from, to: to),
    do: "#{stream_type}/phone_call/#{from}/#{to}"
end
