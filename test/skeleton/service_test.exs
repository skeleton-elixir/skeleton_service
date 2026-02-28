defmodule Skeleton.ServiceTest do
  use Skeleton.Service.TestCase
  alias Skeleton.App.{User, UserCreate}

  setup context do
    service = %UserCreate{
      params: %{
        name: "Jon",
        email: "jon@example.com"
      }
    }

    Map.put(context, :service, service)
  end

  describe "successful transaction" do
    test "creates a user and returns it", context do
      {:ok, user} = UserCreate.perform(context.service)

      assert user.email == "jon@example.com"
      assert user.name == "Jon"
    end

    test "persists the user in the database", context do
      {:ok, user} = UserCreate.perform(context.service)

      db_user = Repo.get(User, user.id)
      assert db_user != nil
      assert db_user.email == "jon@example.com"
    end

    test "runs post-commit functions", context do
      {:ok, user} = UserCreate.perform(context.service)

      # The post-commit function updates the user name
      db_user = Repo.get(User, user.id)
      assert db_user.name == "user updated"
    end
  end

  describe "failed transaction" do
    test "validates required name", context do
      service = %{context.service | params: %{context.service.params | name: ""}}

      {:error, %{errors: errors}} = UserCreate.perform(service)
      assert errors[:name] == {"can't be blank", [validation: :required]}
    end

    test "validates required email", context do
      service = %{context.service | params: %{context.service.params | email: ""}}

      {:error, %{errors: errors}} = UserCreate.perform(service)
      assert errors[:email] == {"can't be blank", [validation: :required]}
    end

    test "does not persist user on validation error", context do
      service = %{context.service | params: %{context.service.params | name: ""}}

      {:error, _changeset} = UserCreate.perform(service)

      assert Repo.aggregate(User, :count) == 0
    end

    test "returns error tuple on validation failure", context do
      service = %{context.service | params: %{context.service.params | name: "", email: ""}}

      result = UserCreate.perform(service)

      assert {:error, %Ecto.Changeset{valid?: false}} = result
    end
  end
end
