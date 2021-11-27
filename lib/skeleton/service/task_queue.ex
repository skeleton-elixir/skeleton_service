defmodule Skeleton.Service.TaskQueue do
  use Agent

  @type task_definition :: {module(), function_name :: atom(), args :: any()}

  @spec start_link(pid()) :: {:ok, pid()} | {:error, any()}
  def start_link(external_pid) do
    Agent.start_link(fn -> [] end, name: name(external_pid))
  end

  @spec enqueue(pid(), task_definition()) :: :ok
  def enqueue(external_pid, task) do
    external_pid
    |> name()
    |> Agent.update(&Enum.concat(&1, [task]))
  end

  @spec tasks(pid()) :: [task_definition()]
  def tasks(external_pid) do
    external_pid
    |> name()
    |> Agent.get(& &1)
  end

  @spec perform(pid()) :: :ok
  def perform(external_pid) do
    external_pid
    |> tasks()
    |> Enum.each(fn {module, function, params} ->
      apply(module, function, params)
    end)
  end

  defp name(pid) do
    String.to_atom("task_queue_for_#{inspect(pid)}")
  end
end
