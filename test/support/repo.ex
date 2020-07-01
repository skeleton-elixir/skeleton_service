defmodule Skeleton.App.Repo do
  use Ecto.Repo, otp_app: :skeleton_service, adapter: Ecto.Adapters.Postgres
end