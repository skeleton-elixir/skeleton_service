defmodule Skeleton.Service.TaskQueueTest do
  use ExUnit.Case, async: true

  alias Skeleton.Service.TaskQueue

  setup do
    {:ok, _pid} = TaskQueue.start_link()
    :ok
  end

  describe "start_link/0" do
    test "returns error when already started" do
      assert {:error, {:already_started, _pid}} = TaskQueue.start_link()
    end
  end

  describe "enqueue/2" do
    test "adds tasks to the queue" do
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 1})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 2})

      assert length(TaskQueue.tasks()) == 2
    end

    test "preserves FIFO order" do
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{order: :first})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{order: :second})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{order: :third})

      [{_, s1}, {_, s2}, {_, s3}] = TaskQueue.tasks()
      assert s1.order == :first
      assert s2.order == :second
      assert s3.order == :third
    end
  end

  describe "tasks/0" do
    test "returns empty list when no tasks enqueued" do
      assert TaskQueue.tasks() == []
    end

    test "returns all enqueued tasks" do
      expected = [
        {&__MODULE__.task_fn/1, %{a: 1}},
        {&__MODULE__.task_fn/1, %{a: 2}}
      ]

      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 1})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 2})

      assert TaskQueue.tasks() == expected
    end
  end

  describe "stop/0" do
    test "stops the agent" do
      TaskQueue.stop()

      # Agent is no longer running, so tasks/0 should exit
      assert catch_exit(TaskQueue.tasks())
    end
  end

  describe "perform/0" do
    test "executes all tasks in order" do
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 1})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 2})

      :ok = TaskQueue.perform()

      assert_received {:task_performed, %{a: 1}}
      assert_received {:task_performed, %{a: 2}}
    end

    test "stops the agent after execution" do
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: 1})
      TaskQueue.perform()

      assert catch_exit(TaskQueue.tasks())
    end

    test "stops the agent even when empty" do
      TaskQueue.perform()

      assert catch_exit(TaskQueue.tasks())
    end

    test "failing task does not prevent other tasks from running" do
      TaskQueue.enqueue(&__MODULE__.failing_fn/1, %{})
      TaskQueue.enqueue(&__MODULE__.task_fn/1, %{a: :after_failure})

      :ok = TaskQueue.perform()

      assert_received {:task_performed, %{a: :after_failure}}
    end

    test "stops agent even when a task fails" do
      TaskQueue.enqueue(&__MODULE__.failing_fn/1, %{})

      :ok = TaskQueue.perform()

      assert catch_exit(TaskQueue.tasks())
    end
  end

  # Helper functions

  def task_fn(service) do
    send(self(), {:task_performed, service})
  end

  def failing_fn(_service) do
    raise "intentional test failure"
  end
end
