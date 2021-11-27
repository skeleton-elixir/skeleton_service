defmodule Skeleton.Service.Server do
  use GenServer

  def start_link(external_pid) do
    GenServer.start_link(__MODULE__, %{external_pid: external_pid, functions_to_call: []},
      name: pid_parser(external_pid)
    )
  end

  def init(state) do
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
