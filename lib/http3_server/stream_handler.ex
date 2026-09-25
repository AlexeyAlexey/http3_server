defmodule Http3Server.StreamHandler do
  use Wtransport.StreamHandler
  require Logger

  alias Wtransport.Stream
  alias Http3Server.PackageStreamHandler.Package, as: PackageHandler

  def handle_stream(
        %Stream{} = _stream,
        %{
          room_id: room_id,
          participant_id: _participant_id,
          custom_params: _custom_params
        } =
          state
      ) do
    PubSub.subscribe(self(), room_id)

    {:continue,
     state
     |> Map.take([
       :room_id,
       :participant_id,
       :custom_params
     ])
     |> Map.put(:package_handler, %{buffer: <<>>, leftover_bytes: 0})}
  end

  @impl Wtransport.StreamHandler
  def handle_data(
        data,
        %Stream{} = stream,
        %{
          room_id: room_id,
          participant_id: participant_id,
          package_handler: package_handler
        } =
          state
      ) do
    if stream.stream_type == :bi do
      {parsed_data, buffer, leftover_bytes} =
        PackageHandler.expand_with(
          data,
          <<participant_id::size(4)-unit(8)>>,
          package_handler[:buffer],
          package_handler[:leftover_bytes]
        )

      package_handler =
        package_handler
        |> Map.put(:buffer, buffer)
        |> Map.put(:leftover_bytes, leftover_bytes)

      state = state |> Map.put(:package_handler, package_handler)

      PubSub.publish(
        room_id,
        {:room_stream, self(), parsed_data}
      )

      {:continue, state}
    else
      {:continue, state}
    end
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
  def handle_info({:room_stream, from, data}, {%Stream{} = stream, state}) do
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
