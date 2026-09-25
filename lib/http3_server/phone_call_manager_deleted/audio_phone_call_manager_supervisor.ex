defmodule Http3Server.AudioPhoneCallManagerSupervisor do
  use DynamicSupervisor

  alias Http3Server.AudioPhoneCallManager, as: AudioPhoneCallManager

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    # Configure the supervisor strategy. Dynamic supervisors typically use :one_for_one.
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Function to start a new child process on demand
  # {:ok, pid} = Http3Server.AudioPhoneCallManagerSupervisor.start_child("#{stream_type}/phone_call/#{from}/#{to}", from: from, to: to)
  def start_child(call_id, opts \\ []) do
    # Define the child specification for the worker process
    name = AudioPhoneCallManager.server(call_id)

    child_spec = %{
      id: name,
      start:
        {Http3Server.AudioPhoneCallManager, :start_link,
         [
           [{:name, name} | opts]
         ]},
      type: :worker,
      # Children of a dynamic supervisor are usually :temporary
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:error, {:already_started, pid}}
    end
  end
end
