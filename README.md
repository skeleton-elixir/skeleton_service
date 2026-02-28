# Skeleton Service

Biblioteca Elixir para criacao de servicos transacionais com `Ecto.Multi`. Encapsula logica de negocio em um pipeline composavel com suporte a tarefas diferidas (pos-commit).

## Instalacao

Adicione ao `mix.exs`:

```elixir
def deps do
  [
    {:skeleton_service, "~> 4.0"}
  ]
end
```

Configure o repo padrao:

```elixir
# config/config.exs
config :skeleton_service, repo: MyApp.Repo
```

## Desenvolvimento local

### Sem Docker

Requisitos: Elixir >= 1.15, PostgreSQL.

```bash
# Instalar dependencias
mix deps.get

# Rodar testes (cria e migra o banco automaticamente)
mix test

# Linter e formatacao
mix credo
mix format --check-formatted
```

Variaveis de ambiente para o banco (opcionais, tem defaults):

| Variavel | Default |
|----------|---------|
| `POSTGRES_HOST` | `localhost` |
| `POSTGRES_USERNAME` | `postgres` |
| `POSTGRES_PASSWORD` | `123456` |

### Com Docker

```bash
# Subir postgres + app
docker compose up

# Rodar testes no container
docker compose run app mix test

# Apenas o postgres (para rodar testes localmente)
docker compose up postgres
```

## Uso

### 1. Criar um service base (opcional)

```elixir
defmodule MyApp.Service do
  import Skeleton.Service

  defmacro __using__(opts) do
    quote do
      use Skeleton.Service, unquote(opts)

      import MyApp.Service
      import Ecto.{Changeset, Query}

      alias MyApp.Repo
    end
  end

  def add_metadata(multi) do
    run(multi, :metadata, fn _service ->
      {:ok, %{created_at: DateTime.utc_now()}}
    end)
  end
end
```

### 2. Criar um servico

```elixir
defmodule MyApp.Accounts.UserCreate do
  use MyApp.Service

  defstruct params: %{}

  def perform(%__MODULE__{} = service) do
    service
    |> begin_transaction()
    |> run(:changeset, &build_changeset/1)
    |> run(:user, &insert_user/1)
    |> commit_transaction()
    |> run(&send_welcome_email/1)
    |> enqueue(&notify_admin/1)
    |> return(:user)
  end

  defp build_changeset(service) do
    changeset =
      %MyApp.User{}
      |> Ecto.Changeset.cast(service.params, [:name, :email])
      |> Ecto.Changeset.validate_required([:name, :email])

    {:ok, changeset}
  end

  defp insert_user(service) do
    MyApp.Repo.insert(service.changeset)
  end

  # Executa imediatamente apos o commit (sincrono)
  defp send_welcome_email(service) do
    MyApp.Mailer.send_welcome(service.user)
  end

  # Enfileirada no TaskQueue, executa quando `return/2` e chamado (diferida)
  defp notify_admin(service) do
    MyApp.Notifications.new_user(service.user)
  end
end
```

### 3. Chamar via contexto

```elixir
defmodule MyApp.Accounts do
  def create_user(params) do
    %MyApp.Accounts.UserCreate{params: params}
    |> MyApp.Accounts.UserCreate.perform()
  end
end
```

## Pipeline

O pipeline de execucao segue esta ordem:

```
begin_transaction -> run/3 (dentro da transacao) -> commit_transaction -> run/2 (pos-commit) -> return
```

| Funcao | Descricao |
|--------|-----------|
| `begin_transaction/1` | Converte a struct em `Ecto.Multi` e inicia o `TaskQueue` |
| `run/3` | Adiciona um passo nomeado ao `Ecto.Multi` (dentro da transacao) |
| `commit_transaction/1` | Executa o `Ecto.Multi` via `Repo.transaction/2` |
| `run/2` | Executa funcao **imediatamente** apos o commit (sincrono) |
| `enqueue/2` | Enfileira tarefa no `TaskQueue`, executada quando `return/2` e chamado (diferida) |
| `return/2` | Extrai resultado nomeado e executa tarefas enfileiradas |

## Comandos uteis

```bash
mix deps.get                    # Instalar dependencias
mix compile                     # Compilar
mix test                        # Rodar testes
mix test path/to/test.exs       # Rodar arquivo especifico
mix test path/to/test.exs:10    # Rodar teste por linha
mix credo                       # Linter
mix format                      # Formatar codigo
mix format --check-formatted    # Verificar formatacao
mix docs                        # Gerar documentacao
```

## Licenca

MIT
