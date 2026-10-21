defmodule Http3Server.StreamHeandlerHealthCheck do
  require Logger

  def update(%{
        call_counter: call_counter,
        speed: speed,
        start_time: start_time,
        logged_at: logged_at
      }) do
    datetime_now = DateTime.utc_now()
    time_diff = datetime_now |> DateTime.diff(start_time, :second)

    if time_diff >= 10 do
      %{
        call_counter: 0,
        speed: (call_counter + 1) / time_diff,
        start_time: datetime_now,
        logged_at: logged_at
      }
    else
      %{
        call_counter: call_counter + 1,
        speed: speed,
        start_time: start_time,
        logged_at: logged_at
      }
    end
  end

  def update(%{health_check: health_check} = state) when is_map(health_check) do
    Map.put(state, :health_check, update(health_check))
  end

  def is_updated(%{health_check: health_check}), do: is_updated(health_check)

  def is_updated(%{call_counter: 0}), do: true
  def is_updated(%{call_counter: _}), do: false

  def logged_at(%{logged_at: _} = healt_check, logged_at),
    do: Map.put(healt_check, :logged_at, logged_at)

  def logged_at(%{health_check: health_check} = state, logged_at)
      when is_map(health_check) do
    Map.put(state, :health_check, logged_at(health_check, logged_at))
  end

  def last_logged(%{logged_at: logged_at}, period, :second) when is_integer(period) do
    time_diff = DateTime.utc_now() |> DateTime.diff(logged_at, :second)

    time_diff >= period
  end

  def last_logged(%{health_check: health_check}, period, unit) when is_map(health_check),
    do: last_logged(health_check, period, unit)

  def log_format(%{call_counter: _call_counter, speed: speed, start_time: _start_time}) do
    "speed: #{speed} handled/s"
  end

  def log_format(%{health_check: health_check}) when is_map(health_check),
    do: log_format(health_check)

  def log_format(_), do: ""
end
