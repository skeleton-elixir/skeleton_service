defmodule Skeleton.ServiceTest do
  use Skeleton.Service.TestCase

  setup context do
    service = %UserCreate{
      params: %{
        name: "Jon",
        email: "jon@example.com"
      }
    }

    Map.put(context, :service, service)
  end

  test "validates required name", context do
    service =
      Map.put(context.service, :params, %{
        context.service.params
        | name: ""
      })

    {:error, %{errors: errors}} = UserCreate.perform(service)
    assert errors[:name] == {"can't be blank", [validation: :required]}
  end

  test "validates required email", context do
    service =
      Map.put(context.service, :params, %{
        context.service.params
        | email: ""
      })

    {:error, %{errors: errors}} = UserCreate.perform(service)
    assert errors[:email] == {"can't be blank", [validation: :required]}
  end

  test "creates a user", context do
    {:ok, user} = UserCreate.perform(context.service)
    assert user.email == "jon@example.com"
    # value before commit
    assert user.name == "Jon"
    # value after commit (should be sending email etc)
    assert Repo.get(User, user.id).name == "user updated"
  end
end
