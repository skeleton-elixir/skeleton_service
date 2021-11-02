defmodule Skeleton.App.UserCreate do
  @moduledoc false

  use Skeleton.App.Service

  alias Skeleton.App.{User, UserCreate}

  defstruct params: %{}

  def perform(%UserCreate{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> add_info()
    |> commit_transaction()
    |> run(&update_user/1)
    |> return(:user)
  end

  # Changeset

  defp changeset(service) do
    changeset =
      %User{}
      |> cast(service.params, [:name, :email])
      |> validate_required([:name, :email])

    {:ok, changeset}
  end

  # Create user

  defp create_user(service) do
    Repo.insert(service.changeset)
  end

  # Update user

  defp update_user(service) do
    {:ok, _} =
      service.user
      |> change(name: "user updated")
      |> Repo.update()
  end
end
