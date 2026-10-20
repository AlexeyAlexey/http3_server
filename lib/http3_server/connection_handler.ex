defmodule Http3Server.ConnectionHandler do
  use Wtransport.ConnectionHandler

  require Logger

  alias Wtransport.Session
  alias Wtransport.Connection
  alias Http3Server.AuthUserConnection
  # alias Http3Server.ConnectionHandlerErrorParser
  alias Http3Server.SessionParameters
  alias Http3Server.PackageStreamHandler.PackageEncoder

  # ConnectionHandler specific callbacks

  @impl Wtransport.ConnectionHandler
  def handle_session(%Session{} = session) do
    with {:ok, %{params: params}} <- SessionParameters.parse(session) do
      case AuthUserConnection.auth(params["auth_token"]) do
        {:ok,
         %{
           room_id: room_id,
           participant_id: participant_id,
           stream_type: stream_type,
           custom_params: custom_params
         }} ->
          state = %{
            room_id: room_id,
            participant_id: participant_id,
            stream_type: stream_type,
            custom_params: custom_params
          }

          Logger.info("Connected: participant id: #{participant_id}; room_id: #{room_id}")

          {:continue, state}

        {:error, msg} ->
          Logger.error(msg)

          {:error, %{error: msg}}
      end
    else
      error ->
        inspect(error)
        |> Logger.error()

        {:error, %{error: error}}
    end
  end

  @impl Wtransport.ConnectionHandler
  def handle_connection(%Connection{} = _connection, state) do
    {:continue, state}
  end

  @impl Wtransport.ConnectionHandler
  def handle_datagram(dgram, %Connection{} = connection, state) do
    :ok = Connection.send_datagram(connection, dgram)

    {:continue, state}
  end

  @impl Wtransport.ConnectionHandler
  def handle_close(%Connection{} = _connection, state) do
    Logger.info("state: #{inspect(state)}")

    :ok
  end

  @impl Wtransport.ConnectionHandler
  def handle_error(
        reason,
        %Connection{} = _connection,
        %{room_id: room_id, stream_type: stream_type, participant_id: participant_id} = state
      )
      when stream_type == "event" do
    Logger.error("state: #{inspect(state)} reason: #{inspect(reason)}")

    if reason =~ "connection closed" do
      {:ok, package} =
        PackageEncoder.encode(:event, %{event_name: "participant_left"}, participant_id)

      Logger.error("state: #{inspect(state)} reason: #{inspect(reason)}")

      :ok =
        PubSub.publish(
          room_id,
          {:room_stream, self(), package}
        )
    end

    :ok
  end

  @impl Wtransport.ConnectionHandler
  def handle_error(reason, %Connection{} = _connection, state) do
    Logger.error("state: #{inspect(state)} reason: #{inspect(reason)}")

    :ok
  end

  # GenServer callbacks

  @impl true
  def handle_continue(_continue_arg, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end

  @impl true
  def handle_info(_msg, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end

  @impl true
  def handle_call(request, _from, {%Connection{} = connection, state}) do
    {:reply, request, {connection, state}}
  end

  @impl true
  def handle_cast(_request, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end
end
