defmodule Sup do
  use GenServer

  @name :sup

  def start_link do
    GenServer.start_link(__MODULE__, [{Worker, :start, []}, {Worker, :start, []}], [
      {:name, @name}
    ])
  end

  def workers do
    GenServer.call(@name, :workers)
  end

  def add(num) do
    GenServer.cast(@name, {:add, num})
  end

  def crash do
    GenServer.cast(@name, :crash)
  end

  def init(spec) do
    Process.flag(:trap_exit, true)

    state = spec |> start_children |> Enum.into(Map.new())

    {:ok, state}
  end

  def handle_cast({:add, number}, state) do
    state |> Map.keys() |> Enum.each(&send(&1, number))
    {:noreply, state}
  end

  def handle_cast(:crash, state) do
    state |> Map.keys() |> Enum.each(&Process.exit(&1, :crash))
    {:noreply, state}
  end

  def handle_call(:workers, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:EXIT, old_pid, reason}, state) do
    IO.inspect(reason)

    case Map.fetch(state, old_pid) do
      {:ok, child_spec} ->
        case restart_child(old_pid, child_spec) do
          {:ok, {pid, child_spec}} ->
            new_state =
              state
              |> Map.delete(old_pid)
              |> Map.put(pid, child_spec)

            {:noreply, new_state}

          :error ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  defp start_children([]), do: []

  defp start_children([spec | rest]) do
    case start_child(spec) do
      {:ok, pid} ->
        [{pid, spec} | start_children(rest)]

      :error ->
        :error
    end
  end

  defp start_child({mod, fun, args}) do
    case apply(mod, fun, args) do
      pid when is_pid(pid) ->
        Process.link(pid)
        {:ok, pid}

      _ ->
        :error
    end
  end

  def restart_child(old_pid, spec) do
    kill(old_pid)
    {:ok, pid} = start_child(spec)
    {:ok, {pid, spec}}
  end

  def kill(pid) do
    Process.exit(pid, :kill)
    :ok
  end
end
