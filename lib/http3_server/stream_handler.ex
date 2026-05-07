defmodule Http3Server.StreamHandler do
  use Wtransport.StreamHandler
  require Logger

  alias Wtransport.Stream

  # StreamHandler specific callbacks

  @impl Wtransport.StreamHandler
  def handle_stream(%Stream{} = _stream, conn_state) do
    state = conn_state

    Logger.info("#{state.stream_type}/#{state.room_id}")
    PubSub.subscribe(self(), "#{state.stream_type}/#{state.room_id}")

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_data(data, %Stream{} = stream, state) do
    if stream.stream_type == :bi do
      # :ok = Stream.send(stream, data)

      # PubSub.subscribe(self(), room_id)

      PubSub.publish("#{state.stream_type}/#{state.room_id}", {:subscribed, self(), data})
    end

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_close(%Stream{} = stream, state) do
    case stream.stream_type do
      :bi -> {:continue, state}
      :uni -> :close
    end
  end

  @impl Wtransport.StreamHandler
  def handle_error(_reason, %Stream{} = _stream, _state) do
    :ok
  end

  # GenServer callbacks

  @impl true
  def handle_continue(_continue_arg, {%Stream{} = stream, state}) do
    {:noreply, {stream, state}}
  end

  @impl true
  def handle_info({:subscribed, from, data}, {%Stream{} = stream, state}) do
    if from != self() do
      :ok = Stream.send(stream, data)
    end

    {:noreply, {stream, state}}
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
