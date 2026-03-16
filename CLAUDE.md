# CLAUDE.md

Este arquivo fornece orientacoes ao Claude Code (claude.ai/code) ao trabalhar com o codigo deste repositorio.

## Visao Geral do Projeto

Skeleton Service e uma biblioteca Elixir (pacote hex) que fornece um padrao de servico para encapsular logica de negocio com gerenciamento de transacoes e execucao de tarefas diferidas. Utiliza o Ecto.Multi para fornecer um pipeline composavel de operacoes no banco de dados.

## Comandos Comuns

```bash
mix deps.get          # Instalar dependencias
mix compile           # Compilar
mix test              # Rodar todos os testes (executa ecto.create + ecto.migrate automaticamente)
mix test test/skeleton/service_test.exs           # Rodar um unico arquivo de teste
mix test test/skeleton/service_test.exs:10        # Rodar um teste especifico por linha
mix credo             # Linter
mix format            # Formatar codigo automaticamente
mix format --check-formatted  # Verificar formatacao sem modificar
```

Requer PostgreSQL. Configure via variaveis de ambiente: `POSTGRES_HOST`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD` (padroes: localhost, postgres, 123456). Banco de teste: `skeleton_service_test`.

## Arquitetura

### Padrao de Pipeline de Servico

Servicos sao structs que implementam uma funcao `perform/1` seguindo este pipeline:

```
validate -> begin_transaction -> run (dentro da transacao) -> commit_transaction -> run (pos-commit) -> enqueue -> return
```

- **`validate/2`** — Valida input antes de abrir conexao com o banco. Retorna struct ou `{:error, reason}`
- **`begin_transaction/1`** — Converte a struct do servico em um `Ecto.Multi` com step `:__input__` (campos da struct) e `:__meta__` (telemetria). Inicializa fila de tarefas no process dictionary se ainda nao existir
- **`run/3`** (nomeado) — Adiciona um passo nomeado ao `Ecto.Multi` (executa dentro da transacao do banco). Callback recebe `merge_input(changes)` (campos da struct + resultados anteriores)
- **`run/2`** (funcional) — Executa uma funcao fora da transacao (efeitos colaterais pos-commit), envolvida em `try/rescue`
- **`enqueue/2`** — Enfileira uma tarefa para executar apos commit bem-sucedido. Tarefas acumulam no process dictionary, compartilhadas entre servicos encadeados
- **`commit_transaction/2`** — Executa o `Ecto.Multi` via `Repo.transaction/2`. Emite evento telemetry
- **`return/2`** — Extrai um resultado nomeado; em caso de sucesso executa as tarefas enfileiradas (se for o servico raiz), em caso de falha limpa a fila e loga warning
- **`c_before_transaction/1`** — Hook overridable chamado antes de `begin_transaction`. Default: no-op
- **`c_after_transaction/1`** — Hook overridable chamado apos `return`. Default: no-op

### Servicos Encadeados

Quando A chama B chama C, a fila de tarefas e compartilhada via process dictionary. Somente A (o servico que iniciou a fila) executa todas as tarefas no seu `return/2`. B e C enfileiram mas nao executam.

### Error Pass-through

Todas as funcoes do pipeline possuem clausulas `{:error, _}` pass-through, permitindo que `validate/2` curto-circuite o pipeline inteiro sem abrir conexao com o banco.

### Telemetry

Eventos emitidos: `[:skeleton, :service, :begin]`, `[:skeleton, :service, :commit]`, `[:skeleton, :service, :stop]`. Metadata inclui `module` e `status`.

### Modulos Principais

- **`Skeleton.Service`** (`lib/skeleton/service.ex`) — Macro principal e funcoes do pipeline. `use Skeleton.Service` injeta validate/transaction/run/enqueue/return/hooks no modulo consumidor.
- **`Skeleton.Service.Config`** (`lib/skeleton/service/config.ex`) — Le o repo e outras configuracoes do application env (`:skeleton_service`).

### Configuracao

O repo padrao e definido na config da aplicacao (`config :skeleton_service, repo: App.Repo`). Servicos individuais podem sobrescreve-lo: `use Skeleton.Service, repo: MyApp.OtherRepo`.

### Estrutura de Config

- `config/config.exs` — Config geral (ecto_repos, repo padrao) + import_config por ambiente
- `config/test.exs` — Config do Repo de teste (pool sandbox, credenciais) e logger
- `config/dev.exs` — Vazio (placeholder para evitar erro no import_config)

### Setup de Testes

Os testes usam um `Skeleton.Service.TestCase` customizado (em `test_helper.exs`) com Ecto SQL Sandbox para isolamento do banco. Modulos de suporte para testes (schema, repo, servicos de exemplo) ficam em `test/skeleton/app/`.
