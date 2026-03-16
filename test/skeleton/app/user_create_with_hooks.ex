defmodule Skeleton.App.UserCreateWithHooks do
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
    |> return(:user)
  end

  def c_before_transaction(service) do
    Process.put(:test_pid, service.test_pid)
    send(service.test_pid, {:hook, :before_transaction})
    service
  end

  def c_after_transaction(result) do
    test_pid = Process.get(:test_pid)
    if test_pid, do: send(test_pid, {:hook, :after_transaction, result})
    result
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
end
