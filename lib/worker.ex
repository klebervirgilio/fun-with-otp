defmodule Worker do
  def start do
    spawn(fn -> loop(0) end)
  end

  def loop(sum \\ 0) do
    receive do
      :exit ->
        :ok

      :crash ->
        1 / 0

      number when is_integer(number) ->
        sum = sum + number
        loop(sum)
    end
  end
end
