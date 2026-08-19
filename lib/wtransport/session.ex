defmodule Wtransport.Session do
  defstruct [:path, :headers, :authority]
  @type t :: %__MODULE__{path: String.t(), headers: Keyword.t(), authority: String.t()}
end
