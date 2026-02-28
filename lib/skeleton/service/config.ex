defmodule Skeleton.Service.Config do
  @moduledoc """
  Reads configuration for the `:skeleton_service` application.
  """

  @doc """
  Returns the configured Ecto repo module.
  """
  @spec repo() :: module() | nil
  def repo, do: config(:repo)

  @doc """
  Reads a configuration value for `:skeleton_service`.

  Returns `default` if the key is not set.
  """
  @spec config(atom(), any()) :: any()
  def config(key, default \\ nil) do
    Application.get_env(:skeleton_service, key, default)
  end
end
