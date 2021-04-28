use Mix.Config

config :skeleton_service, ecto_repos: [Skeleton.App.Repo]

config :skeleton_service, Skeleton.App.Service, repo: Skeleton.App.Repo

config :skeleton_service, Skeleton.App.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "skeleton_service_test",
  password: System.get_env("POSTGRES_PASSWORD", "123456"),
  username: System.get_env("POSTGRES_USERNAME", "postgres")

config :logger, :console, level: :error
