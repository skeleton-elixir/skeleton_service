defmodule Skeleton.App.Service do
  defmacro __using__(_) do
    quote do
      use Skeleton.Service, repo: Skeleton.App.Repo
      import Ecto.{Changeset, Query}
      alias Skeleton.App.{Repo, User, UserCreate}
    end
  end
end