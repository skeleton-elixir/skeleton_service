defmodule Skeleton.Service.Config do
  def repo, do: config(:repo)

  def config(key, default \\ nil) do
    Application.get_env(:skeleton_service, key, default)
  end
end
