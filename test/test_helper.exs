defmodule Skeleton.Service.TestCase do
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ExUnit.Case, unquote(opts)
      import Ecto.Query
      import Ecto.Changeset
      alias Ecto.Adapters.SQL
      alias Skeleton.Service.{Repo, UserCreate, User}
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Skeleton.Service.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Skeleton.Service.Repo, {:shared, self()})
  end
end

Skeleton.Service.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Skeleton.Service.Repo, :manual)

ExUnit.start()