defmodule Skeleton.App.Repo.Migrations.CreateUsers do
  use Skeleton.App, :migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string)
      add(:email, :string)

      timestamps()
    end
  end
end
