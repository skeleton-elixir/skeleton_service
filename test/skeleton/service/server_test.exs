defmodule Skeleton.Service.ServerTest do
  use Skeleton.Service.TestCase

  alias Skeleton.Service.Server

  setup ctx do
    {:ok, pid} = Server.start_link(self())

    ctx
    |> Map.put(:pid, pid)
  end

  test "enqueue_task" do
    Server.enqueue_task(self(), {__MODULE__, :function_to_run, [1]})
    Server.enqueue_task(self(), {__MODULE__, :function_to_run, [2]})
    Server.enqueue_task(self(), {__MODULE__, :function_to_run, [3]})

    functions_to_call = Server.get_state(self()).functions_to_call

    assert functions_to_call == [
             {Skeleton.Service.ServerTest, :function_to_run, [1]},
             {Skeleton.Service.ServerTest, :function_to_run, [2]},
             {Skeleton.Service.ServerTest, :function_to_run, [3]}
           ]
  end

  test "perform", ctx do
    Server.enqueue_task(self(), {__MODULE__, :function_to_run, [1]})
    reply = Server.perform(self())

    assert reply.external_pid == self()
    assert reply.functions_to_call == [{Skeleton.Service.ServerTest, :function_to_run, [1]}]
    refute Process.alive?(ctx.pid)
  end

  test "stop", ctx do
    assert Process.alive?(ctx.pid)
    Server.stop(self())
    refute Process.alive?(ctx.pid)
  end

  describe "kill_if_not_alive" do
    test "stop server if parent not alive", ctx do
      fake_pid = :c.pid(0,999,11)
      send(ctx.pid, {:kill_if_not_alive, fake_pid})
      :timer.sleep(5)
      refute Process.alive?(ctx.pid)
    end

    test "keep server started if parent alive", ctx do
      send(ctx.pid, {:kill_if_not_alive, self()})
      :timer.sleep(5)
      assert Process.alive?(ctx.pid)
    end
  end

  def function_to_run(_), do: nil
end
