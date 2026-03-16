defmodule Skeleton.App.UserCreateInner do
  @moduledoc """
  Inner service called by UserCreateChained.
  Enqueues tasks that should be executed by the outer service's return.
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
    |> enqueue(&task_inner/1)
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

  defp task_inner(service) do
    send(service.test_pid, {:enqueued, :inner, service.user})
  end
end
