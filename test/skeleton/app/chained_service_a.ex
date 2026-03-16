defmodule Skeleton.App.ChainedServiceA do
  @moduledoc "Root service (A) in A → B → C chain. Calls B in post-commit."

  use Skeleton.App.Service

  alias Skeleton.App.User

  @enforce_keys [:params, :test_pid]
  defstruct params: %{}, test_pid: nil

  def perform(%__MODULE__{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> commit_transaction()
    |> enqueue(&task_a/1)
    |> run(&call_service_b/1)
    |> return(:user)
  end

  defp changeset(service) do
    changeset =
      %User{}
      |> cast(service.params, [:name, :email])
      |> validate_required([:name, :email])

    {:ok, changeset}
  end

  defp create_user(service) do
    Repo.insert(service.changeset)
  end

  defp task_a(service) do
    send(service.test_pid, {:enqueued, :task_a})
  end

  defp call_service_b(service) do
    inner =
      struct!(Skeleton.App.ChainedServiceB,
        params: %{name: "User B", email: "b@example.com"},
        test_pid: service.test_pid
      )

    Skeleton.App.ChainedServiceB.perform(inner)

    # Checkpoint: B already returned (and C inside it too),
    # but enqueues should NOT have fired yet
    send(service.test_pid, {:checkpoint, :after_b_returned})
  end
end
