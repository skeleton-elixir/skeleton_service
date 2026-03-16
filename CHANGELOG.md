5.0.0
------
#### Breaking
* TaskQueue Agent eliminado — tarefas enfileiradas agora sao armazenadas em fila no process dictionary, compartilhada entre servicos encadeados
* Campos da struct consolidados em um unico step `:__input__` no `Ecto.Multi` (antes era um step por campo)
* Callbacks de steps `run/3` agora recebem map com `merge_input` (campos da struct + resultados anteriores, sem chaves internas)

#### Features
* `validate/2` — valida input antes de abrir conexao com o banco; retorna `{:error, reason}` sem tocar no DB
* Hooks `c_before_transaction/1` e `c_after_transaction/1` — callbacks sobrescreviveis para logging, audit, etc.
* Telemetry — eventos emitidos em `[:skeleton, :service, :begin]`, `[:skeleton, :service, :commit]`, `[:skeleton, :service, :stop]`
* `@enforce_keys` guidance — warning em compile-time se struct nao define `@enforce_keys`
* Servicos encadeados: A chama B chama C — todos enqueues sao executados somente no `return/2` do servico raiz (A)

#### Changes
* Adicionada dependencia `{:telemetry, "~> 1.0"}`
* `Skeleton.Service.TaskQueue` removido
* Error pass-through (`{:error, _}`) em todas as funcoes do pipeline para suportar `validate/2`

4.0.0
------
#### Breaking
* Versao minima do Elixir: `~> 1.15` (anteriormente `~> 1.8`)

#### Changes
* Dependencias atualizadas: `ecto_sql ~> 3.12`, `postgrex ~> 0.19`, `ex_doc ~> 0.34`, `credo ~> 1.7`
* Substituido `use Mix.Config` (deprecated) por `import Config`; config de teste movida para `config/test.exs`
* TaskQueue: `enqueue/2` agora usa prepend O(1) em vez de append O(n)
* TaskQueue: `name/0` usa tupla `{:global, {__MODULE__, self()}}` em vez de string interpolation
* TaskQueue: `perform/0` envolve cada tarefa em `try/rescue` — falha em uma tarefa nao impede as demais
* TaskQueue: `perform/0` usa `try/after` para garantir que `stop()` sempre executa
* Service: `run/2` (pos-commit) envolve funcao em `try/rescue` — erro nao invalida resultado commitado
* Service: `return/2` com erro agora emite `Logger.warning` com nome da operacao que falhou
* Service: `begin_transaction/2` separa `queue_pid` e `queue_started_here?` como steps proprios do Multi
* Adicionados `@moduledoc`, `@doc` e `@spec` em todos os modulos e funcoes publicas
* Dockerfile reescrito com multi-stage build e imagem slim
* docker-compose.yml: PostgreSQL 17-alpine com healthcheck, servico `app`, volumes para cache
* Cobertura de testes expandida: 7 testes (2 duplicados) para 23 testes
* README.md reescrito com instrucoes completas de uso e desenvolvimento

3.1.0
------
#### Changes
* Added repo opts support on commit_transaction

3.0.0
------
#### Changes
* Simplify service usage

2.0.0
------
#### Changes
* Added new config repo

1.3.1
------
#### Changes
* Updated README.md.

1.3.0
------
#### Changes
* Remove MIX_ENV enviroment from Docker.

1.2.0
------
#### Changes
* Added ex_doc package.

1.1.0
------
#### Changes
* Added package info.

1.0.0
------
#### Changes
* First release.