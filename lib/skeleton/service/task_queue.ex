defmodule Skeleton.Service.TaskQueue do
  @moduledoc """
  Agent-based queue for deferred tasks that run after a successful transaction commit.

  Each TaskQueue is scoped to the calling process via a global name tuple,
  allowing multiple concurrent services to maintain independent queues.

  Tasks are enqueued during the transaction pipeline and executed only after
  the transaction commits successfully. If any task fails during execution,
  remaining tasks still run and the error is logged.
  """

  use Agent

  require Logger

  @doc """
  Starts a new TaskQueue agent linked to the calling process.

  Returns `{:ok, pid}` on success or `{:error, {:already_started, pid}}`
  if a queue for this process already exists.
  """
  @spec start_link() :: {:ok, pid()} | {:error, any()}
  def start_link do
    Agent.start_link(fn -> [] end, name: name())
  end

  @doc """
  Stops the TaskQueue agent for the current process.
  """
  @spec stop() :: :ok
  def stop do
    Agent.stop(name())
  end

  @doc """
  Enqueues a task function and associated service data for deferred execution.

  Uses prepend (O(1)) internally; order is restored on retrieval.
  """
  @spec enqueue(function(), struct()) :: :ok
  def enqueue(fun, service) do
    Agent.update(name(), &[{fun, service} | &1])
  end

  @doc """
  Returns the list of enqueued tasks in FIFO order.
  """
  @spec tasks() :: [{function(), struct()}]
  def tasks do
    Agent.get(name(), &Enum.reverse/1)
  end

  @doc """
  Executes all enqueued tasks in FIFO order, then stops the agent.

  Each task is wrapped in `try/rescue` so a failing task does not prevent
  the remaining tasks from executing. Errors are logged via `Logger.error/1`.
  The agent is always stopped, even if tasks fail.
  """
  @spec perform() :: :ok
  def perform do
    try do
      Enum.each(tasks(), fn {fun, service} ->
        try do
          fun.(service)
        rescue
          e ->
            Logger.error("TaskQueue task failed: #{Exception.format(:error, e, __STACKTRACE__)}")
        end
      end)
    after
      stop()
    end
  end

  defp name do
    {:global, {__MODULE__, self()}}
  end
end
