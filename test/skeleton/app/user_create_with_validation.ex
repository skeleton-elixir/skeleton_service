defmodule Skeleton.App.UserCreateWithValidation do
  @moduledoc false

  use Skeleton.App.Service

  alias Skeleton.App.User

  @enforce_keys [:params]
  defstruct params: %{}

  def perform(%__MODULE__{} = service) do
    service
    |> validate(&check_params/1)
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> commit_transaction()
    |> return(:user)
  end

  defp check_params(%__MODULE__{params: params} = service) do
    cond do
      not is_map(params) ->
        {:error, :invalid_params}

      Map.get(params, :name) in [nil, ""] ->
        {:error, :name_required}

      Map.get(params, :email) in [nil, ""] ->
        {:error, :email_required}

      true ->
        service
    end
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
