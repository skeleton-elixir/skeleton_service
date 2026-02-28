defmodule Skeleton.Service.ConfigTest do
  use ExUnit.Case, async: true

  alias Skeleton.Service.Config
  alias Skeleton.App.Repo

  describe "repo/0" do
    test "returns the configured repo module" do
      assert Config.repo() == Repo
    end
  end

  describe "config/2" do
    test "returns configured value for known key" do
      assert Config.config(:repo) == Repo
    end

    test "returns nil for unconfigured key" do
      assert Config.config(:nonexistent_key) == nil
    end

    test "returns default when key is not configured" do
      assert Config.config(:nonexistent_key, :fallback) == :fallback
    end

    test "configured value takes precedence over default" do
      assert Config.config(:repo, :some_default) == Repo
    end
  end
end
