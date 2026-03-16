defmodule Skeleton.ServiceTest do
  use Skeleton.Service.TestCase

  alias Skeleton.App.{User, UserCreate}

  setup context do
    service = %UserCreate{
      params: %{
        name: "Jon",
        email: "jon@example.com"
      }
    }

    Map.put(context, :service, service)
  end

  describe "successful transaction" do
    test "creates a user and returns it", context do
      {:ok, user} = UserCreate.perform(context.service)

      assert user.email == "jon@example.com"
      assert user.name == "Jon"
    end

    test "persists the user in the database", context do
      {:ok, user} = UserCreate.perform(context.service)

      db_user = Repo.get(User, user.id)
      assert db_user != nil
      assert db_user.email == "jon@example.com"
    end

    test "runs post-commit functions", context do
      {:ok, user} = UserCreate.perform(context.service)

      # The post-commit function updates the user name
      db_user = Repo.get(User, user.id)
      assert db_user.name == "user updated"
    end
  end

  describe "failed transaction" do
    test "validates required name", context do
      service = %{context.service | params: %{context.service.params | name: ""}}

      {:error, %{errors: errors}} = UserCreate.perform(service)
      assert errors[:name] == {"can't be blank", [validation: :required]}
    end

    test "validates required email", context do
      service = %{context.service | params: %{context.service.params | email: ""}}

      {:error, %{errors: errors}} = UserCreate.perform(service)
      assert errors[:email] == {"can't be blank", [validation: :required]}
    end

    test "does not persist user on validation error", context do
      service = %{context.service | params: %{context.service.params | name: ""}}

      {:error, _changeset} = UserCreate.perform(service)

      assert Repo.aggregate(User, :count) == 0
    end

    test "returns error tuple on validation failure", context do
      service = %{context.service | params: %{context.service.params | name: "", email: ""}}

      result = UserCreate.perform(service)

      assert {:error, %Ecto.Changeset{valid?: false}} = result
    end
  end

  describe "validate/2" do
    alias Skeleton.App.UserCreateWithValidation

    test "passes validation and creates user" do
      service = %UserCreateWithValidation{
        params: %{name: "Jon", email: "jon@example.com"}
      }

      assert {:ok, user} = UserCreateWithValidation.perform(service)
      assert user.name == "Jon"
    end

    test "returns error without opening database connection" do
      service = %UserCreateWithValidation{
        params: %{name: "", email: "jon@example.com"}
      }

      assert {:error, :name_required} = UserCreateWithValidation.perform(service)
      assert Repo.aggregate(User, :count) == 0
    end

    test "returns error for missing email" do
      service = %UserCreateWithValidation{
        params: %{name: "Jon", email: ""}
      }

      assert {:error, :email_required} = UserCreateWithValidation.perform(service)
    end

    test "returns error for invalid params" do
      service = %UserCreateWithValidation{params: "not a map"}

      assert {:error, :invalid_params} = UserCreateWithValidation.perform(service)
    end

    test "error propagates through entire pipeline" do
      service = %UserCreateWithValidation{
        params: %{name: "", email: ""}
      }

      result = UserCreateWithValidation.perform(service)

      assert {:error, :name_required} = result
      # No user should be created
      assert Repo.aggregate(User, :count) == 0
    end
  end

  describe "enqueue/2" do
    alias Skeleton.App.UserCreateWithEnqueue

    test "executes enqueued tasks in FIFO order" do
      service = %UserCreateWithEnqueue{
        params: %{name: "Jon", email: "jon@example.com"},
        test_pid: self()
      }

      {:ok, user} = UserCreateWithEnqueue.perform(service)

      assert_received {:enqueued, :task_one, ^user}
      assert_received {:enqueued, :task_two, ^user}
    end

    test "does not execute enqueued tasks on transaction error" do
      service = %UserCreateWithEnqueue{
        params: %{name: "", email: ""},
        test_pid: self()
      }

      {:error, _changeset} = UserCreateWithEnqueue.perform(service)

      refute_received {:enqueued, _, _}
    end

    test "failing enqueue task does not prevent subsequent tasks" do
      alias Skeleton.App.UserCreateWithFailingEnqueue

      service = %UserCreateWithFailingEnqueue{
        params: %{name: "Jon", email: "jon@example.com"},
        test_pid: self()
      }

      {:ok, _user} = UserCreateWithFailingEnqueue.perform(service)

      assert_received {:enqueued, :after_failure}
    end
  end

  describe "enqueue/2 with chained services" do
    alias Skeleton.App.UserCreateChained

    test "outer service executes all enqueued tasks from both services" do
      service = %UserCreateChained{
        params: %{name: "Outer", email: "outer@example.com"},
        test_pid: self()
      }

      {:ok, _user} = UserCreateChained.perform(service)

      assert_received {:enqueued, :outer, _}
      assert_received {:enqueued, :inner, _}
    end

    test "inner service does not execute enqueued tasks on its own" do
      service = %UserCreateChained{
        params: %{name: "Outer", email: "outer@example.com"},
        test_pid: self()
      }

      {:ok, _user} = UserCreateChained.perform(service)

      # Both messages should arrive (inner was executed by outer's return)
      messages = collect_enqueue_messages()
      assert length(messages) == 2
      assert {:enqueued, :outer, _} = Enum.find(messages, &match?({:enqueued, :outer, _}, &1))
      assert {:enqueued, :inner, _} = Enum.find(messages, &match?({:enqueued, :inner, _}, &1))
    end
  end

  describe "hooks" do
    alias Skeleton.App.UserCreateWithHooks

    test "c_before_transaction is called before transaction", context do
      service = %UserCreateWithHooks{
        params: context.service.params,
        test_pid: self()
      }

      {:ok, _user} = UserCreateWithHooks.perform(service)

      assert_received {:hook, :before_transaction}
    end

    test "c_after_transaction is called after return on success", context do
      service = %UserCreateWithHooks{
        params: context.service.params,
        test_pid: self()
      }

      {:ok, _user} = UserCreateWithHooks.perform(service)

      assert_received {:hook, :after_transaction, {:ok, _user}}
    end

    test "c_after_transaction is called after return on error" do
      service = %UserCreateWithHooks{
        params: %{name: "", email: ""},
        test_pid: self()
      }

      {:error, _changeset} = UserCreateWithHooks.perform(service)

      assert_received {:hook, :after_transaction, {:error, _changeset}}
    end

    test "default hooks are no-ops", context do
      # UserCreate (without hooks override) should work normally
      {:ok, user} = UserCreate.perform(context.service)
      assert user.name == "Jon"
    end
  end

  describe "telemetry" do
    test "emits begin, commit, and stop events on success", context do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach_many(
        "test-#{inspect(ref)}",
        [
          [:skeleton, :service, :begin],
          [:skeleton, :service, :commit],
          [:skeleton, :service, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      {:ok, _user} = UserCreate.perform(context.service)

      assert_received {:telemetry, [:skeleton, :service, :begin], %{system_time: _},
                       %{module: Skeleton.App.UserCreate}}

      assert_received {:telemetry, [:skeleton, :service, :commit], %{system_time: _},
                       %{module: Skeleton.App.UserCreate, status: :ok}}

      assert_received {:telemetry, [:skeleton, :service, :stop], %{duration: duration},
                       %{module: Skeleton.App.UserCreate, status: :ok}}

      assert is_integer(duration)
      assert duration >= 0

      :telemetry.detach("test-#{inspect(ref)}")
    end

    test "emits stop with error status on failed transaction" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach_many(
        "test-#{inspect(ref)}",
        [
          [:skeleton, :service, :begin],
          [:skeleton, :service, :commit],
          [:skeleton, :service, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      service = %UserCreate{params: %{name: "", email: ""}}
      {:error, _changeset} = UserCreate.perform(service)

      assert_received {:telemetry, [:skeleton, :service, :begin], _, _}

      assert_received {:telemetry, [:skeleton, :service, :commit], _, %{status: :error}}

      assert_received {:telemetry, [:skeleton, :service, :stop], %{duration: _},
                       %{status: :error}}

      :telemetry.detach("test-#{inspect(ref)}")
    end
  end

  describe "enqueue/2 with 3 chained services (A → B → C)" do
    alias Skeleton.App.ChainedServiceA

    test "enqueues from all 3 services are executed only at root (A) return" do
      service = %ChainedServiceA{
        params: %{name: "User A", email: "a@example.com"},
        test_pid: self()
      }

      {:ok, _user} = ChainedServiceA.perform(service)

      # Collect all messages in the order they were received
      messages = collect_all_messages()

      # Checkpoints must come BEFORE any enqueue execution.
      # This proves C.return and B.return did NOT execute the queue.
      checkpoint_c_idx = Enum.find_index(messages, &match?({:checkpoint, :after_c_returned}, &1))
      checkpoint_b_idx = Enum.find_index(messages, &match?({:checkpoint, :after_b_returned}, &1))
      enqueue_a_idx = Enum.find_index(messages, &match?({:enqueued, :task_a}, &1))
      enqueue_b_idx = Enum.find_index(messages, &match?({:enqueued, :task_b}, &1))
      enqueue_c_idx = Enum.find_index(messages, &match?({:enqueued, :task_c}, &1))

      # All indices must be present
      assert checkpoint_c_idx != nil, "expected :after_c_returned checkpoint"
      assert checkpoint_b_idx != nil, "expected :after_b_returned checkpoint"
      assert enqueue_a_idx != nil, "expected :task_a enqueue"
      assert enqueue_b_idx != nil, "expected :task_b enqueue"
      assert enqueue_c_idx != nil, "expected :task_c enqueue"

      # C returned before B returned
      assert checkpoint_c_idx < checkpoint_b_idx

      # ALL checkpoints came before ANY enqueue execution
      assert checkpoint_b_idx < enqueue_a_idx
      assert checkpoint_b_idx < enqueue_b_idx
      assert checkpoint_b_idx < enqueue_c_idx
    end

    test "enqueues execute in FIFO order (A, C, B) — C enqueues before B since it runs inside B's transaction" do
      service = %ChainedServiceA{
        params: %{name: "User A", email: "a@example.com"},
        test_pid: self()
      }

      {:ok, _user} = ChainedServiceA.perform(service)

      messages = collect_all_messages()

      enqueue_msgs =
        Enum.filter(messages, fn
          {:enqueued, _} -> true
          _ -> false
        end)

      # C enqueues before B because C runs inside B's run/3 (before B's commit)
      assert [{:enqueued, :task_a}, {:enqueued, :task_c}, {:enqueued, :task_b}] = enqueue_msgs
    end

    test "all 3 users are persisted in the database" do
      service = %ChainedServiceA{
        params: %{name: "User A", email: "a@example.com"},
        test_pid: self()
      }

      {:ok, _user} = ChainedServiceA.perform(service)

      assert Repo.aggregate(User, :count) == 3
    end

    test "process dictionary queue is cleaned up after root return" do
      service = %ChainedServiceA{
        params: %{name: "User A", email: "a@example.com"},
        test_pid: self()
      }

      {:ok, _user} = ChainedServiceA.perform(service)

      assert Process.get(:__skeleton_service_queue__) == nil
    end
  end

  # Helpers

  defp collect_all_messages(acc \\ []) do
    receive do
      msg -> collect_all_messages([msg | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  defp collect_enqueue_messages(acc \\ []) do
    receive do
      {:enqueued, _, _} = msg -> collect_enqueue_messages([msg | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end
end
