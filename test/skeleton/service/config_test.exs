defmodule Skeleton.Service.ConfigTest do
  use Skeleton.Service.TestCase

  alias Skeleton.Service.Config
  alias Skeleton.App.Repo

  test "returns repo from config.exs" do
    assert Config.repo() == Repo
  end
end
