defmodule Skeleton.App.ChainedServiceB do
  @moduledoc "Middle service (B) in A → B → C chain. Calls C inside transaction."

  use Skeleton.App.Service

  alias Skeleton.App.User

  @enforce_keys [:params, :test_pid]
  defstruct params: %{}, test_pid: nil

  def perform(%__MODULE__{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> run(:inner_user, &call_service_c/1)
    |> commit_transaction()
    |> enqueue(&task_b/1)
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

  defp task_b(service) do
    send(service.test_pid, {:enqueued, :task_b})
  end

  defp call_service_c(service) do
    inner =
      struct!(Skeleton.App.ChainedServiceC,
        params: %{name: "User C", email: "c@example.com"},
        test_pid: service.test_pid
      )

    result = Skeleton.App.ChainedServiceC.perform(inner)

    # Checkpoint: C already returned, but enqueues should NOT have fired yet
    send(service.test_pid, {:checkpoint, :after_c_returned})

    result
  end
end
