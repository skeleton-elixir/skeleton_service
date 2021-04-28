defmodule Skeleton.Service.ConfigTest do
  use Skeleton.Service.TestCase

  alias Skeleton.Service.Config
  alias Skeleton.App.{Repo, Service}

  test "returns repo from config.exs" do
    assert Config.repo(:skeleton_service, Service) == Repo
  end
end
