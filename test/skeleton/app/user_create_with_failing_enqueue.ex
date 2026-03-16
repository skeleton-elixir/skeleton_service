defmodule Skeleton.App.UserCreateWithFailingEnqueue do
  @moduledoc false

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
    |> enqueue(&failing_task/1)
    |> enqueue(&succeeding_task/1)
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

  defp failing_task(_service) do
    raise "intentional enqueue failure"
  end

  defp succeeding_task(service) do
    send(service.test_pid, {:enqueued, :after_failure})
  end
end
