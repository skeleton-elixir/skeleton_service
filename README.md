# Sobre o Skeleton Service

O Skeleton Service é um facilitador para criação de serviços em sua aplicação.
Um serviço nada mais é do que uma ação ou evento que sua aplicaçao executa, por exemplo: criar uma conta de usuário,
atualizar perfil, login, logout etc.

## Instalação e configuração

```elixir
# mix.exs

def deps do
  [
    {:skeleton_service, "~> 3.1.0"}
  ]
end
```

```elixir
# config/config.exs

config :skeleton_service, repo: App.Repo # Default repo
```

```elixir
# lib/app/service.ex

defmodule App.Service do
  import App.Service

  defmacro __using__(opts) do
    quote do
      use Skeleton.Service, unquote(opts)

      import App.Service
      import Ecto.{Changeset, Query}

      alias App.Repo
    end
  end

  # You can create your own service functions
  def my_custom_function(multi) do
    run(multi, :info, fn _service ->
      {:ok, "INFO"}
    end)
  end
end
```

## Criando os serviços

```elixir
# lib/app/accounts/user/user_create.ex

defmodule App.Accounts.UserCreate do
  use App.Service

  alias App.User.Accounts

  defstruct params: %{}

  def perform(%__MODULE__{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:user, &create_user/1)
    |> my_custom_function()
    |> commit_transaction()
    |> run(&send_confirmation_code/1)
    |> return(:user)
  end

  # Changeset

  defp changeset(service) do
    changeset =
      %Accounts.User{}
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
    Accounts.send_user_confirmation_code(service.user)
  end
end

```

```elixir
# lib/app/accounts/user/user_update.ex

defmodule App.Accounts.UserUpdate do
  use App.Service, repo: App.Repo # Override the default Repo

  alias App.Accounts

  @enforce_keys [:user, :params]
  defstruct user: nil, params: nil

  def perform(%__MODULE__{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &changeset/1)
    |> run(:updated_user, &update_user/1)
    |> commit_transaction()
    |> return(:updated_user)
  end

  # Changeset

  defp changeset(service) do
    changeset =
      service.user
      |> cast(service.params, [:name])
      |> validate_required([:name])

    {:ok, changeset}
  end

  # Update User

  defp update_user(service) do
    Repo.update(service.changeset)
  end
end
```

## Criando o contexto

```elixir
# lib/app/accounts/accounts.ex

defmodule App.Accounts do
  alias App.Accounts

  def create_user(params) do
    %Accounts.UserCreate{
      params: params
    }
    |> Accounts.UserCreate.perform()
  end

  def update_user(user, params) do
    %Accounts.UserUpdate{
      user: user,
      params: params
    }
    |> Accounts.UserUpdate.perform()
  end

  def send_user_confirmation_code(user) do
    %UserSendConfirmationCode{
      user: user
    }
    |> UserSendConfirmationCode.perform()
  end
end
```

## Exemplos de chamada dos serviços

```elixir
App.Accounts.create_user(%{
  email: "email@example.com"
})

App.Accounts.update_user(user, %{
  name: "Updated name"
})
```