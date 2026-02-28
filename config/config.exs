import Config

config :skeleton_service, ecto_repos: [Skeleton.App.Repo]

config :skeleton_service, repo: Skeleton.App.Repo

import_config "#{config_env()}.exs"
