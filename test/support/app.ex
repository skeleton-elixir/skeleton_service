defmodule Skeleton.Service.App do
  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :naive_datetime_usec]
    end
  end

  def service do
    quote do
      use Skeleton.Service, repo: Skeleton.Service.Repo
      import Ecto.{Changeset, Query}
      alias Skeleton.Service.{Repo, User, UserCreate}
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
