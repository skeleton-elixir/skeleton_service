defmodule Skeleton.Service.TaskQueueTest do
  use Skeleton.Service.TestCase

  alias Skeleton.Service.TaskQueue

  setup ctx do
    {:ok, pid} = TaskQueue.start_link(self())

    ctx
    |> Map.put(:pid, pid)
  end

  test "tasks" do
    tasks_to_perform = [
      {__MODULE__, :function_to_run, [1]},
      {__MODULE__, :function_to_run, [2]},
    ]

    TaskQueue.enqueue(self(), List.first(tasks_to_perform))
    TaskQueue.enqueue(self(), List.last(tasks_to_perform))

    assert TaskQueue.tasks(self()) == tasks_to_perform
  end

  test "enqueue" do
    tasks_to_perform = [
      {__MODULE__, :function_to_run, [1]},
      {__MODULE__, :function_to_run, [2]},
    ]

    TaskQueue.enqueue(self(), List.first(tasks_to_perform))
    TaskQueue.enqueue(self(), List.last(tasks_to_perform))

    assert TaskQueue.tasks(self()) == tasks_to_perform
  end

  test "perform" do
    TaskQueue.enqueue(self(), {__MODULE__, :function_to_run, [1]})
    :ok = TaskQueue.perform(self())

    assert_received :task_performed
  end

  def function_to_run(_) do
    send(self(), :task_performed)
  end
end
