defmodule Http3Server.StreamHandler do
  # use Wtransport.StreamHandler
  @impl :webtransport_handler

  require Logger

  # alias Wtransport.Stream
  alias Http3Server.ConnectionHandler
  alias Wtransport.Session
  alias Http3Server.PhoneCallManager
  alias Http3Server.PackageStreamHandler.Package, as: PackageHandler

  # StreamHandler specific callbacks

  def origin_check(headers, opts) do
    #  -> accept | {reject, 400..599, binary()}
    :accept
  end

  @impl :webtransport_handler
  def init(session, req, _opts) do
    with {:ok, connection_params} <-
           struct(Session, req)
           |> ConnectionHandler.handle_session(),
         {:ok, state} <- init_stream(connection_params) do
      # init_uni_out(session)

      {:ok,
       state
       |> Map.put(:session, session)
       |> Map.put(:streams, %{})
       |> Map.put(:out_uni_streams, %{})}
    else
      {:error, "call was dropped"} ->
        {:error, "call was dropped"}

      _error ->
        {:error, "unexpected error"}
    end
  end

  def init_uni_out(session) do
    spawn(fn ->
      {:ok, stream} = :webtransport.open_stream(session, :uni)
      send(session, {:uni_out_stream_opened, stream})
    end)
  end

  def init_stream(
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
        {:ok, state |> Map.take([:from, :to, :direction, :stream_type, :type])}

      {:error, "call was dropped"} ->
        {:error, "call was dropped"}
    end
  end

  def init_stream(
        %{
          conference_id: conference_id,
          participant_id: _participant_id,
          stream_type: stream_type,
          type: "conference" = type,
          custom_params: _custom_params
        } =
          state
      ) do
    Phoenix.PubSub.subscribe(Http3Server.PubSub, "#{type}/#{stream_type}/#{conference_id}")

    {:ok,
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

  @impl :webtransport_handler
  def handle_stream(
        _stream,
        :bidi,
        data,
        %{from: from, to: to, direction: _direction, stream_type: stream_type, type: "phone_call"} =
          state
      ) do
    PhoneCallManager.send_data_to_stream(
      stream_type: stream_type,
      from: from,
      to: to,
      data: data
    )

    {:ok, state, []}
  end

  @impl :webtransport_handler
  def handle_stream(
        stream,
        :bidi = handled_stream_type,
        data,
        %{
          stream_type: stream_type,
          participant_id: participant_id,
          conference_id: conference_id,
          type: "conference" = type,
          package_handler: package_handler,
          session: session,
          out_uni_streams: out_uni_streams
        } =
          state
      ) do
    state =
      if is_nil(state[:bidi_stream]) do
        state |> Map.put(:bidi_stream, stream)
      else
        state
      end

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

    # spawn(fn ->
    #   :webtransport.send(session, uni_stream, parsed_data)
    #   # |> IO.inspect(label: "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk")
    # end)

    Phoenix.PubSub.broadcast(
      Http3Server.PubSub,
      "#{type}/#{stream_type}/#{conference_id}",
      {:conference_stream, session, stream, handled_stream_type, parsed_data}
    )

    {:ok, state}
  end

  @impl :webtransport_handler
  def handle_stream(
        stream,
        :uni = handled_stream_type,
        data,
        %{
          stream_type: stream_type,
          participant_id: participant_id,
          conference_id: conference_id,
          type: "conference" = type,
          package_handler: package_handler,
          session: session
        } =
          state
      ) do
    state =
      if Map.has_key?(state.streams, stream) do
        state
      else
        new_streams = Map.put(state.streams, stream, %{type: :bidi})
        %{state | streams: new_streams}
      end

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

    Phoenix.PubSub.broadcast(
      Http3Server.PubSub,
      "#{type}/#{stream_type}/#{conference_id}",
      {:conference_stream, session, stream, handled_stream_type, parsed_data}
    )

    {:ok, state, []}
  end

  @impl :webtransport_handler
  def handle_stream_closed(stream_id, _reason, state) do
    new_streams = Map.delete(state.streams, stream_id)
    state = %{state | streams: new_streams}

    {:ok, state}
  end

  # GenServer callbacks

  def handle_info({:phone_call_stream, from, data}, state) do
    # if from != self() do
    #   :ok = Stream.send(stream, data)
    # end

    {:ok, state}
  end

  def handle_info(
        {:conference_stream, from_session, from_stream, :bidi, parsed_data},
        %{session: session, bidi_stream: bidi_stream} = state
      ) do
    if from_session != session do
      {:ok, state, [{:send, bidi_stream, parsed_data}]}
    else
      {:ok, state}
    end
  end

  def handle_info(
        {:conference_stream, _from_session, _from_stream, :bidi, _parsed_data},
        state
      ) do
    {:ok, state}
  end

  def handle_info(
        {:conference_stream, from_session, from_stream, :uni, parsed_data},
        %{session: session, out_uni_streams: out_uni_streams} = state
      ) do
    uni_stream = out_uni_streams |> Map.keys() |> List.first()

    # if from_session != session && not is_nil(uni_stream) do
    if from_session != session do
      spawn(fn ->
        :webtransport.send(session, uni_stream, parsed_data)
      end)

      # {:ok, state, [{:send, uni_stream, parsed_data}]}
      {:ok, state}
    else
      {:ok, state}
    end

    {:ok, state}
  end

  def handle_info({:uni_out_stream_opened, stream}, state) do
    out_uni_streams =
      if Map.has_key?(state, :out_uni_streams) do
        Map.put(state.out_uni_streams, stream, %{})
      else
        %{stream => %{}}
      end

    {:ok,
     state
     |> Map.put(:out_uni_streams, out_uni_streams)}
  end

  def handle_info(info, state) do
    # if from != self() do
    #   :ok = Stream.send(stream, data)
    # end

    IO.inspect(info, label: "info")

    {:ok, state}
  end

  @impl :webtransport_handler
  def terminate(reason, _state) do
    IO.inspect(reason)
    :ok
  end

  # @impl true
  # def handle_info(
  #       :waiting_time_expired,
  #       {%Stream{} = stream, %{type: "phone_call", from: from, to: to} = state}
  #     ) do
  #   Logger.info("waiting_time_expired from: #{from} to: #{to}")

  #   {:stop, :normal, {stream, state}}
  # end

  # def handle_info(
  #       {:end_call, "user_ended_call"},
  #       {%Stream{} = stream,
  #        %{type: "phone_call", from: from, to: to, direction: direction} = state}
  #     ) do
  #   Logger.info(
  #     "one of participants ended a call direction: #{direction} from: #{from} to: #{to}"
  #   )

  #   {:stop, :normal, {stream, state}}
  # end

  # @impl true
  # def handle_call(request, _from, {%Stream{} = stream, state}) do
  #   {:reply, request, {stream, state}}
  # end

  # @impl true
  # def handle_cast(_request, {%Stream{} = stream, state}) do
  #   {:noreply, {stream, state}}
  # end
end
