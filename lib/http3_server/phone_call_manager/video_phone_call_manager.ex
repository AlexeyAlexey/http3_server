defmodule Http3Server.VideoPhoneCallManager do
  use GenServer

  alias Http3Server.VideoPhoneCallManagerSupervisor
  alias Http3Server.PhoneCallManager

  # TODO implement reconnection
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
        %{
          custom_params: custom_params,
          direction: "outcome",
          from: from,
          to: to,
          type: "phone_call"
        }
      ) do
    PhoneCallManager.call_id(from: from, to: to)
    |> VideoPhoneCallManagerSupervisor.start_child(
      caller_pid: caller_pid,
      from: from,
      to: to,
      receiver_custom_params: custom_params
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # {:error, {:already_started, pid}}
        reconnect(
          caller_pid,
          %{
            custom_params: custom_params,
            direction: "outcome",
            type: "phone_call",
            from: from,
            to: to
          }
        )

        {:ok, pid}
    end
  end

  def connect(
        receiver_pid,
        %{
          custom_params: custom_params,
          direction: "income",
          type: "phone_call",
          from: from,
          to: to
        }
      ) do
    with {:ok, _pid} <-
           PhoneCallManager.call_id(from: from, to: to) |> lookup_manager() do
      responded("phone_call/#{from}/#{to}", %{
        receiver_pid: receiver_pid,
        caller_custom_params: custom_params
      })
    else
      {:error, :not_found} ->
        {:error, "call was dropped"}
    end
  end

  def reconnect(
        caller_pid,
        %{
          custom_params: custom_params,
          direction: "outcome",
          type: "phone_call",
          from: from,
          to: to
        }
      ) do
    PhoneCallManager.call_id(from: from, to: to)
    |> server()
    |> GenServer.call(
      {:reconnect, %{caller_pid: caller_pid, receiver_custom_params: custom_params}}
    )
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
          type: "phone_call",
          from: from,
          to: to,
          reason: _reason
        } = params
      ) do
    PhoneCallManager.call_id(from: from, to: to)
    |> server()
    |> GenServer.call({:end_call, params})
  end

  @impl true
  def handle_call(
        {:reconnect, %{caller_pid: caller_pid, receiver_custom_params: receiver_custom_params}},
        _from,
        state
      ) do
    # if state[:caller_pid] do
    #   # check if alive
    #   # send command to terminate
    # end

    state =
      state
      |> Map.put(:caller_pid, caller_pid)
      |> Map.put(:receiver_custom_params, receiver_custom_params)

    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(
        {:responded, %{receiver_pid: receiver_pid, caller_custom_params: caller_custom_params}},
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
      |> Map.put(:caller_custom_params, caller_custom_params)

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
    state =
      state
      |> Map.put(:caller_pid, nil)
      |> Map.put(:receiver_pid, nil)
      |> Map.put(:connection_status, :disconnected)
      |> Map.drop([:caller_custom_params, :receiver_custom_params])

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
