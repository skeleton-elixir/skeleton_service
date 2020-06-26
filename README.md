# Sobre o Skeleton Service

O Skeleton Service é um facilitador para criação de serviços em sua aplicação.
Um serviço nada mais é do que uma ação ou evento que sua aplicaçao executa, por exemplo: criar uma conta de usuário,
atualizar perfil, login, logout etc.

## Instalação

```elixir
def deps do
  [
    {:skeleton_service, github: "diegonogueira/skeleton_service"},
  ]
end
```

## Criando o serviço

```elixir
defmodule App.Service do
  defmacro __using__(_) do
    quote do
      use Skeleton.Service, repo: App.Repo
      import Ecto.{Changeset, Query}
      alias App.Repo
    end
  end
end
```

```elixir
defmodule App.Accounts.UserCreate do
  use App.Service
  alias App.User.Accounts.{
    UserCreate,
    UserSendConfirmationCode
  }

  defstruct params: %{}

  def perform(%UserCreate{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> commit_transaction()
    |> run(&send_confirmation_code/1)
    |> return(:user)
  end

  # Changeset

  defp changeset(service) do
    changeset =
      %User{}
      |> cast(service.params, [:email])
      |> validate_required([:email])

    {:ok, changeset}
  end

  # Create user

  defp create_user(service) do
    Repo.insert(service.changeset)
  end

  # Send confirmation code

  defp send_confirmation_code(service) do
    %UserSendConfirmationCode{
      resource: service.user
    }
    |> UserSendConfirmationCode.perform()
  end
end

```

## Criando o contexto

```elixir
defmodule App.Accounts do
  alias App.Accounts.UserCreate

  def create_user(params) do
    %UserCreate{
      params: params,
    }
    |> UserCreate.perform()
  end
end
```

## Exemplo de chamada do serviço

```elixir
App.Accounts.create_user(%{
  params: %{
    email: "email@example.com"
  }
})
```