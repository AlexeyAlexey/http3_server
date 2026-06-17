defmodule Http3Server.CallBeep do
  # seconds
  @repeat_after 3000
  @mp3_binary File.read!(Path.join([__DIR__, "../../../priv/sounds/call_beep.mp3"]))

  def play, do: @mp3_binary

  def repeat_after, do: @repeat_after

  # def get_mp3_binary do
  #   Path.join(:code.priv_dir(:http3_server), "sounds/call_beep.mp3")
  #   |> File.read!()
  # end
end
