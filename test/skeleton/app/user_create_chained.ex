defmodule Skeleton.App.UserCreateChained do
  @moduledoc """
  Top-level service that chains to UserCreateInner.
  Used to test that enqueue works across nested service calls.
  """

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
    |> enqueue(&task_outer/1)
    |> run(&call_inner_service/1)
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

  defp task_outer(service) do
    send(service.test_pid, {:enqueued, :outer, service.user})
  end

  defp call_inner_service(service) do
    inner =
      struct!(Skeleton.App.UserCreateInner,
        params: %{name: "Inner User", email: "inner@example.com"},
        test_pid: service.test_pid
      )

    Skeleton.App.UserCreateInner.perform(inner)
  end
end
