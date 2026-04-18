defmodule Http3Server.StreamHandler do
  use Wtransport.StreamHandler

  alias Wtransport.Stream

  # StreamHandler specific callbacks

  @impl Wtransport.StreamHandler
  def handle_stream(%Stream{} = _stream, conn_state) do
    state = conn_state

    IO.inspect("#{state.stream_type}/#{state.room_id}", label: "11111111111111111111111")
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
    #    const view = new DataView(payload);
    # //   const participantId = view.getUint32(0, false);
    # //   const seq = view.getUint32(4, false);
    # //   const type = view.getUint32(8, false);
    # //   const key = view.getUint32(12, false);
    # //   // const ts = view.getUint32(16, false);
    # //   const ts = view.getBigUint64(16, false);
    # //   const byteLength = view.getUint32(32, false);

    # //   const videoChunk = new Uint8Array(payload, 36, byteLength);

    # //   // console.log(`participantId: #${participantId}, chunkCount: ${chunkCount}; size: ${videoChunk.byteLength} byte`);

    if from != self() do
      # IO.inspect(data)

      # <<participant_id::32, seq::32, type::32, key::32, ts::64, length::32, binary_blob::binary>> =
      #   data

      # IO.inspect([participant_id, seq, type, key, ts, length, byte_size(data)],
      #   label: "ddddddddddddddddddddddddd"
      # )

      :ok = Stream.send(stream, data)
    end

    # IO.inspect(data, label: "subscribed")

    # :ok = Stream.send(stream, data)

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
