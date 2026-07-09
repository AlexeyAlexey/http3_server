defmodule Http3Server.StreamHandler do
  use Wtransport.StreamHandler
  require Logger

  alias Wtransport.Stream
  alias Http3Server.PhoneCallManager

  # StreamHandler specific callbacks

  @impl Wtransport.StreamHandler
  def handle_stream(
        %Stream{} = _stream,
        %{
          custom_params: custom_params,
          from: from,
          to: to,
          direction: direction,
          stream_type: stream_type,
          type: "phone_call" = type
        } =
          state
      ) do
    Logger.info(
      "direction: #{direction}; #{state.stream_type}/phone_call/#{state.from}/#{state.to}"
    )

    PhoneCallManager.connect(self(), %{
      custom_params: custom_params,
      from: from,
      to: to,
      direction: direction,
      stream_type: stream_type,
      type: type
    })
    |> case do
      {:ok, _} ->
        {:continue, state |> Map.take([:from, :to, :direction, :stream_type, :type])}

      {:error, "call was dropped"} ->
        :close
    end
  end

  def handle_stream(
        %Stream{} = _stream,
        %{
          conference_id: conference_id,
          participant_id: _participant_id,
          stream_type: stream_type,
          type: "conference" = type,
          custom_params: _custom_params
        } =
          state
      ) do
    PubSub.subscribe(self(), "#{type}/#{stream_type}/#{conference_id}")

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

  def handle_stream(%Stream{} = _stream, state) do
    Logger.info("#{state.stream_type}/#{state.room_id}")
    PubSub.subscribe(self(), "#{state.stream_type}/#{state.room_id}")

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_data(
        data,
        %Stream{} = stream,
        %{from: from, to: to, direction: _direction, stream_type: stream_type, type: "phone_call"} =
          state
      ) do
    if stream.stream_type == :bi do
      PhoneCallManager.send_data_to_stream(
        stream_type: stream_type,
        from: from,
        to: to,
        data: data
      )
    end

    {:continue, state}
  end

  def handle_data(data, %Stream{} = stream, state) do
    if stream.stream_type == :bi do
      PubSub.publish("#{state.stream_type}/#{state.room_id}", {:subscribed, self(), data})
    end

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_close(%Stream{} = stream, state) do
    Logger.info("stream type: #{inspect(stream.stream_type)} state: #{inspect(state)}")

    case stream.stream_type do
      :bi -> {:continue, state}
      :uni -> :close
    end
  end

  @impl Wtransport.StreamHandler
  def handle_error(reason, %Stream{} = _stream, state) do
    Logger.error("reason: #{inspect(reason)} state: #{inspect(state)}")
    :ok
  end

  # GenServer callbacks

  @impl true
  def handle_continue(_continue_arg, {%Stream{} = stream, state}) do
    {:noreply, {stream, state}}
  end

  @impl true
  def handle_info({:phone_call_stream, from, data}, {%Stream{} = stream, state}) do
    if from != self() do
      :ok = Stream.send(stream, data)
    end

    {:noreply, {stream, state}}
  end

  @impl true
  def handle_info(
        :waiting_time_expired,
        {%Stream{} = stream, %{type: "phone_call", from: from, to: to} = state}
      ) do
    Logger.info("waiting_time_expired from: #{from} to: #{to}")

    {:stop, :normal, {stream, state}}
  end

  def handle_info(
        {:end_call, "user_ended_call"},
        {%Stream{} = stream,
         %{type: "phone_call", from: from, to: to, direction: direction} = state}
      ) do
    Logger.info(
      "one of participants ended a call direction: #{direction} from: #{from} to: #{to}"
    )

    {:stop, :normal, {stream, state}}
  end

  @impl true
  def handle_call(request, _from, {%Stream{} = stream, state}) do
    {:reply, request, {stream, state}}
  end

  @impl true
  def handle_cast(_request, {%Stream{} = stream, state}) do
    {:noreply, {stream, state}}
  end
end
