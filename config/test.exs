use Mix.Config

config :skeleton_service, ecto_repos: [Skeleton.Service.Repo]

config :skeleton_service, Skeleton.Service.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "skeleton_service_test",
  username: System.get_env("SKELETON_SERVICE_DB_USER") || System.get_env("USER") || "postgres"

config :logger, :console, level: :error