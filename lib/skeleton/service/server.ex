defmodule Skeleton.Service.Server do
  use GenServer

  def start_link(external_pid) do
    GenServer.start_link(__MODULE__, %{external_pid: external_pid, functions_to_call: []},
      name: pid_parser(external_pid)
    )
  end

  def init(state) do
    Process.send_after(self(), {:kill_if_not_alive, state.external_pid}, 5_000)

    {:ok, state}
  end

  def enqueue_task(external_pid, {module, function, params}) do
    external_pid
    |> pid_parser()
    |> GenServer.cast({:enqueue_task, module, function, params})
  end

  def perform(external_pid) do
    external_pid
    |> pid_parser()
    |> GenServer.call(:perform)
  end

  def stop(external_pid) do
    external_pid
    |> pid_parser()
    |> GenServer.stop(:normal, :infinity)
  end

  def get_state(external_pid) do
    external_pid
    |> pid_parser()
    |> GenServer.call(:get_state)
  end

  # Handles

  def handle_cast({:enqueue_task, module, function, params}, state) do
    state =
      put_in(state, [:functions_to_call], state.functions_to_call ++ [{module, function, params}])

    {:noreply, state}
  end

  def handle_call(:perform, _from, state) do
    Enum.each(state.functions_to_call, fn {module, function, params} ->
      apply(module, function, params)
    end)

    {:stop, :normal, state, []}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:kill_if_not_alive, parent_pid}, state) do
    if Process.alive?(parent_pid) do
      Process.send_after(self(), {:kill_if_not_alive, parent_pid}, 5_000)
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  # Helpers

  defp pid_parser(pid) do
    pid_string = inspect(pid)

    ~r"\#PID<(.*?)>"
    |> Regex.scan(pid_string, capture: :all_but_first)
    |> List.flatten()
    |> hd()
    |> String.to_atom()
  end
end
