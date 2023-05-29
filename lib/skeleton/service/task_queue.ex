defmodule Skeleton.Service.TaskQueue do
  use Agent

  @spec start_link() :: {:ok, pid()} | {:error, any()}
  def start_link() do
    Agent.start_link(fn -> [] end, name: name())
  end

  @spec stop() :: :ok
  def stop do
    Agent.stop(name())
  end

  @spec enqueue(function(), struct()) :: :ok
  def enqueue(fun, service) do
    Agent.update(name(), &(&1 ++ [{fun, service}]))
  end

  @spec tasks() :: [{function(), struct()}]
  def tasks() do
    Agent.get(name(), & &1)
  end

  @spec perform() :: :ok
  def perform() do
    Enum.each(tasks(), fn {fun, service} ->
      fun.(service)
    end)

    stop()
  end

  defp name() do
    {:global, "task_queue_for_#{inspect(self())}"}
  end
end
