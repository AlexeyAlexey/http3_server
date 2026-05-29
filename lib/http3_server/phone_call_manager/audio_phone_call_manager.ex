defmodule Http3Server.AudioPhoneCallManager do
  use GenServer

  @waiting_time 30000

  alias Http3Server.AudioPhoneCallManagerSupervisor
  alias Http3Server.CallBeep
  alias Http3Server.PhoneCallManager

  # TODO terminate process when call is ended
  def start_link(opts) do
    name =
      Keyword.get(opts, :name)

    GenServer.start_link(
      __MODULE__,
      opts,
      name: name
    )
    |> case do
      {:ok, pid} ->
        Process.send_after(pid, :send_beep_to_caller, 1000)
        Process.send_after(pid, :check_if_responded, @waiting_time)

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:error, {:already_started, pid}}
    end
  end

  ## Callbacks

  @impl true
  def init(opts) do
    {:ok,
     Keyword.delete(opts, :name)
     |> Map.new()
     |> Map.put(:responded, false)
     |> Map.put(:connection_status, :connected)}
  end

  def state(call_id) do
    server(call_id)
    |> GenServer.call(:state)
  end

  def connect(
        caller_pid,
        %{direction: "outcome", type: "phone_call" = type, from: from, to: to}
      ) do
    PhoneCallManager.call_id(type: type, from: from, to: to)
    |> AudioPhoneCallManagerSupervisor.start_child(
      caller_pid: caller_pid,
      from: from,
      to: to
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        reconnect(
          caller_pid,
          %{direction: "outcome", type: "phone_call", from: from, to: to}
        )

        {:ok, pid}
    end
  end

  def connect(
        receiver_pid,
        %{direction: "income", type: "phone_call" = type, from: from, to: to}
      ) do
    with {:ok, _pid} <-
           PhoneCallManager.call_id(type: type, from: from, to: to) |> lookup_manager() do
      responded("phone_call/#{from}/#{to}", %{receiver_pid: receiver_pid})
    else
      {:error, :not_found} ->
        {:error, "call was dropped"}
    end
  end

  def reconnect(
        caller_pid,
        %{direction: "outcome", type: "phone_call" = type, from: from, to: to}
      ) do
    PhoneCallManager.call_id(type: type, from: from, to: to)
    |> server()
    |> GenServer.call({:reconnect, %{caller_pid: caller_pid}})
  end

  def responded(call_id, data) when is_binary(call_id) and is_map(data) do
    server(call_id)
    |> GenServer.call({:responded, data})
  end

  def play_ringtone(call_id, data) do
    server(call_id)
    |> GenServer.cast({:play_ringtone, data})
  end

  def end_call(
        %{
          direction: _direction,
          type: "phone_call" = type,
          from: from,
          to: to,
          reason: _reason
        } = params
      ) do
    PhoneCallManager.call_id(type: type, from: from, to: to)
    |> server()
    |> GenServer.call({:end_call, params})
  end

  @impl true
  def handle_call(
        {:reconnect, %{caller_pid: caller_pid}},
        _from,
        %{receiver_pid: receiver_pid} = state
      ) do
    # if state[:caller_pid] do
    #   # check if alive
    #   # send command to terminate
    # end

    state =
      if receiver_pid && Process.alive?(receiver_pid) do
        Map.put(state, :responded, true)
      else
        Map.put(state, :responded, false)
      end

    Process.send_after(self(), :send_beep_to_caller, 1000)

    if !state[:responded] do
      Process.send_after(self(), :check_if_responded, @waiting_time)
    end

    state =
      state
      |> Map.put(:caller_pid, caller_pid)
      |> Map.put(:connection_status, :connected)

    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(
        {:responded, %{receiver_pid: receiver_pid}},
        _from,
        state
      ) do
    # if state[:receiver_pid] do
    #   # check if alive
    #   # send command to terminate
    # end

    state =
      state
      |> Map.put(:receiver_pid, receiver_pid)
      |> Map.put(:responded, true)

    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(
        :state,
        _from,
        state
      ) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(
        {:end_call,
         %{
           direction: _direction,
           type: "phone_call" = _type,
           from: _,
           to: _to,
           reason: reason
         }},
        _from,
        state
      ) do
    # TODO encapsulate <<"M", "S", package_size::32, 3::8, reason::binary>>
    # TODO encapsulate "video/phone_call/#{state.from}/#{state.to}"

    reason_size = byte_size(reason)
    # 3::8 is 1 byte
    package_size = 1 + reason_size

    PubSub.publish(
      "video/phone_call/#{state.from}/#{state.to}",
      {:subscribed, self(), <<"M", "S", package_size::32, 3::8, reason::binary>>}
    )

    PubSub.publish(
      "audio/phone_call/#{state.from}/#{state.to}",
      {:subscribed, self(), <<"M", "S", package_size::32, 3::8, reason::binary>>}
    )

    PubSub.publish(
      "audio/phone_call/#{state.from}/#{state.to}",
      {:end_call, reason}
    )

    PubSub.publish(
      "video/phone_call/#{state.from}/#{state.to}",
      {:end_call, reason}
    )

    state =
      state
      |> Map.put(:responded, false)
      |> Map.put(:caller_pid, nil)
      |> Map.put(:receiver_pid, nil)
      |> Map.put(:connection_status, :disconnected)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(
        {:play_ringtone, data},
        state
      ) do
    PubSub.publish("audio/phone_call/#{state.from}/#{state.to}", {:subscribed, self(), data})

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :send_beep_to_caller,
        %{responded: responded} = state
      ) do
    if !responded && state[:connection_status] == :connected do
      PubSub.publish(
        "audio/phone_call/#{state.from}/#{state.to}",
        {:subscribed, self(), CallBeep.play()}
      )

      Process.send_after(self(), :send_beep_to_caller, CallBeep.repeat_after())
    end

    {:noreply, state}
  end

  def handle_info(
        :check_if_responded,
        state
      ) do
    if !state.responded do
      PubSub.publish(
        "audio/phone_call/#{state.from}/#{state.to}",
        {:subscribed, self(), <<"M", "S", 21::32, 3::8, "waiting_time_expired">>}
      )

      PubSub.publish(
        "video/phone_call/#{state.from}/#{state.to}",
        {:subscribed, self(), <<"M", "S", 21::32, 3::8, "waiting_time_expired">>}
      )

      PubSub.publish(
        "audio/phone_call/#{state.from}/#{state.to}",
        :waiting_time_expired
      )

      PubSub.publish(
        "video/phone_call/#{state.from}/#{state.to}",
        :waiting_time_expired
      )
    end

    state = if state.responded, do: state, else: Map.put(state, :connection_status, :disconnected)

    {:noreply, state}
  end

  @doc """
  Looks up the given writer.
  """
  # lookup_manager(call_id)
  def lookup_manager(call_id) do
    server(call_id)
    |> GenServer.whereis()
    |> case do
      nil -> {:error, :not_found}
      pid -> {:ok, pid}
    end
  end

  def name(call_id), do: call_id

  def server(call_id), do: name(call_id) |> via()

  defp via(name), do: {:via, Registry, {AudioPhoneCallManager, name}}
end
