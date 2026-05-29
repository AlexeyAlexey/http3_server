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
        caller_pid,
        %{direction: direction, stream_type: "audio", type: "phone_call", from: from, to: to}
      ) do
    AudioPhoneCallManager.connect(
      caller_pid,
      %{direction: direction, type: "phone_call", from: from, to: to}
    )
  end

  def connect(
        receiver_pid,
        %{direction: direction, stream_type: "video", type: "phone_call", from: from, to: to}
      ) do
    VideoPhoneCallManager.connect(receiver_pid, %{
      direction: direction,
      type: "phone_call",
      from: from,
      to: to
    })
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

  def call_id(
        type: "phone_call" = type,
        from: from,
        to: to
      ) do
    "#{type}/#{from}/#{to}"
  end
end
