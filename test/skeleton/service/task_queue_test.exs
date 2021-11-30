defmodule Skeleton.Service.TaskQueueTest do
  use Skeleton.Service.TestCase

  alias Skeleton.Service.TaskQueue

  setup ctx do
    {:ok, pid} = TaskQueue.start_link()

    ctx
    |> Map.put(:pid, pid)
  end

  test "tasks" do
    tasks_to_perform = [
      {&__MODULE__.function_to_run/1, %{a: 1}},
      {&__MODULE__.function_to_run/1, %{a: 2}},
    ]

    TaskQueue.enqueue(
      tasks_to_perform |> List.first() |> elem(0),
      tasks_to_perform |> List.first() |> elem(1)
    )

    TaskQueue.enqueue(
      tasks_to_perform |> List.last() |> elem(0),
      tasks_to_perform |> List.last() |> elem(1)
    )

    assert TaskQueue.tasks() == tasks_to_perform
  end

  test "enqueue" do
    tasks_to_perform = [
      {&__MODULE__.function_to_run/1, %{a: 1}},
      {&__MODULE__.function_to_run/1, %{a: 2}},
    ]

    TaskQueue.enqueue(
      tasks_to_perform |> List.first() |> elem(0),
      tasks_to_perform |> List.first() |> elem(1)
    )

    TaskQueue.enqueue(
      tasks_to_perform |> List.last() |> elem(0),
      tasks_to_perform |> List.last() |> elem(1)
    )

    assert TaskQueue.tasks() == tasks_to_perform
  end

  test "perform" do
    TaskQueue.enqueue(&__MODULE__.function_to_run/1, %{a: 1})
    TaskQueue.enqueue(&__MODULE__.function_to_run/1, %{a: 2})

    :ok = TaskQueue.perform()

    assert_received :task_performed
    assert_received :task_performed
  end

  def function_to_run(_) do
    send(self(), :task_performed)
  end
end
