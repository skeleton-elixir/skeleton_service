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
begin_transaction -> run (dentro da transacao) -> commit_transaction -> run (pos-commit) -> return
```

- **`begin_transaction/1`** — Converte a struct do servico em um `Ecto.Multi`, inicia um agent `TaskQueue` para trabalho diferido
- **`run/3`** (nomeado) — Adiciona um passo nomeado ao `Ecto.Multi` (executa dentro da transacao do banco)
- **`run/2`** (funcional) — Executa uma funcao fora da transacao (efeitos colaterais pos-commit), envolvida em `try/rescue`
- **`enqueue/2`** — Enfileira uma tarefa para executar apos commit bem-sucedido via agent TaskQueue
- **`commit_transaction/2`** — Executa o `Ecto.Multi` via `Repo.transaction/2`
- **`return/2`** — Extrai um resultado nomeado; em caso de sucesso executa as tarefas enfileiradas, em caso de falha para a fila e loga warning

### Modulos Principais

- **`Skeleton.Service`** (`lib/skeleton/service.ex`) — Macro principal e funcoes do pipeline. `use Skeleton.Service` injeta transaction/run/enqueue/return no modulo consumidor.
- **`Skeleton.Service.TaskQueue`** (`lib/skeleton/service/task_queue.ex`) — Fila baseada em Agent para tarefas diferidas. Usa nomenclatura global com tupla `{__MODULE__, self()}`. Tarefas sao enfileiradas com prepend O(1) e executadas em ordem FIFO. Cada tarefa e envolvida em `try/rescue` para resiliencia.
- **`Skeleton.Service.Config`** (`lib/skeleton/service/config.ex`) — Le o repo e outras configuracoes do application env (`:skeleton_service`).

### Configuracao

O repo padrao e definido na config da aplicacao (`config :skeleton_service, repo: App.Repo`). Servicos individuais podem sobrescreve-lo: `use Skeleton.Service, repo: MyApp.OtherRepo`.

### Estrutura de Config

- `config/config.exs` — Config geral (ecto_repos, repo padrao) + import_config por ambiente
- `config/test.exs` — Config do Repo de teste (pool sandbox, credenciais) e logger
- `config/dev.exs` — Vazio (placeholder para evitar erro no import_config)

### Setup de Testes

Os testes usam um `Skeleton.Service.TestCase` customizado (em `test_helper.exs`) com Ecto SQL Sandbox para isolamento do banco. Modulos de suporte para testes (schema, repo, servicos de exemplo) ficam em `test/skeleton/app/`. Atualmente 23 testes cobrindo TaskQueue, Config e Service.
