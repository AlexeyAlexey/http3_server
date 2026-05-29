defmodule Http3Server.VideoPhoneCallManager do
  use GenServer

  alias Http3Server.VideoPhoneCallManagerSupervisor
  alias Http3Server.PhoneCallManager

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
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:error, {:already_started, pid}}
    end
  end

  ## Callbacks

  @impl true
  def init(opts) do
    {:ok, Keyword.delete(opts, :name) |> Map.new() |> Map.put(:responded, false)}
  end

  def state(call_id) do
    server(call_id)
    |> GenServer.call(:state)
  end

  def connect(
        caller_pid,
        %{direction: "outcome", from: from, to: to, type: "phone_call" = type}
      ) do
    PhoneCallManager.call_id(type: type, from: from, to: to)
    |> VideoPhoneCallManagerSupervisor.start_child(
      caller_pid: caller_pid,
      from: from,
      to: to
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # {:error, {:already_started, pid}}
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
        state
      ) do
    # if state[:caller_pid] do
    #   # check if alive
    #   # send command to terminate
    # end

    IO.inspect("video")

    state =
      state
      |> Map.put(:caller_pid, caller_pid)

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
           reason: _reason
         }},
        _from,
        state
      ) do
    IO.inspect("video end_call")
    {:reply, :ok, state}
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

  defp via(name), do: {:via, Registry, {VideoPhoneCallManager, name}}
end
