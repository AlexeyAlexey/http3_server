defmodule Http3Server.StreamHandler do
  use Wtransport.StreamHandler
  require Logger

  alias Wtransport.Stream
  alias Http3Server.PackageStreamHandler.Package, as: PackageHandler
  alias Http3Server.PackageStreamHandler.PackageDecoder
  alias Http3Server.StreamHeandlerHealthCheck
  # alias Http3Server.PackageStreamHandler.PackageEncoder

  def handle_stream(
        %Stream{} = _stream,
        %{
          room_id: room_id,
          participant_id: _participant_id,
          custom_params: _custom_params
        } =
          state
      ) do
    :ok = PubSub.subscribe(self(), room_id)

    {:continue,
     state
     |> Map.take([
       :room_id,
       :participant_id,
       :stream_type,
       :custom_params
     ])
     |> Map.put(:package_handler, %{buffer: <<>>, leftover_bytes: 0})
     |> Map.put(:health_check, %{
       call_counter: 0,
       speed: 0,
       start_time: DateTime.utc_now(),
       logged_at: DateTime.utc_now()
     })}
  end

  @impl Wtransport.StreamHandler
  def handle_data(
        data,
        %Stream{stream_type: :bi},
        %{
          room_id: room_id,
          participant_id: participant_id,
          stream_type: stream_type,
          package_handler: package_handler,
          health_check: _health_check
        } =
          state
      )
      when stream_type in ["video", "audio"] do
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

    state =
      state
      |> Map.put(:package_handler, package_handler)

    state =
      if stream_type in ["video", "audio"] do
        StreamHeandlerHealthCheck.update(state)
      else
        state
      end

    if stream_type in ["video", "audio"] && StreamHeandlerHealthCheck.is_updated(state) do
      Logger.info(
        "health check: #{StreamHeandlerHealthCheck.log_format(state)}; participant id: #{participant_id}; stream_type: #{stream_type};"
      )
    end

    if byte_size(parsed_data) > 0 do
      :ok =
        PubSub.publish(
          room_id,
          {:room_stream, self(), parsed_data}
        )
    end

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_data(
        data,
        %Stream{stream_type: :bi},
        %{
          room_id: _room_id,
          participant_id: _participant_id,
          stream_type: stream_type,
          package_handler: package_handler
        } =
          state
      )
      when stream_type == "event" do
    # TODO Implement
    {decoded_package, buffer, leftover_bytes} =
      PackageDecoder.decode(data, package_handler[:buffer], package_handler[:leftover_bytes])

    package_handler =
      package_handler
      |> Map.put(:buffer, buffer)
      |> Map.put(:leftover_bytes, leftover_bytes)

    state = state |> Map.put(:package_handler, package_handler)

    if byte_size(decoded_package) > 0 do
      Http3Server.PackageStreamHandler.PackageParser.parse(decoded_package)
      # |> IO.inspect(label: "-----------------")
    end

    Logger.info("Event")

    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_data(
        _data,
        %Stream{stream_type: _},
        state
      ) do
    {:continue, state}
  end

  @impl Wtransport.StreamHandler
  def handle_close(%Stream{} = stream, %{stream_type: stream_type} = state)
      when stream_type in ["audio", "video"] do
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
