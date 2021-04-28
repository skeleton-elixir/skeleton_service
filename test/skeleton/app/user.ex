defmodule Skeleton.App.User do
  use Skeleton.App, :schema

  schema "users" do
    field :name, :string
    field :email, :string

    timestamps()
  end
end
