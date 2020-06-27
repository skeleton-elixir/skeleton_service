defmodule Skeleton.Service.User do
  use Skeleton.Service.App, :schema

  schema "users" do
    field :name, :string
    field :email, :string

    timestamps()
  end
end