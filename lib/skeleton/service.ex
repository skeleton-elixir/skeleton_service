defmodule Skeleton.Service do
  @moduledoc """
  Provides a composable service pipeline built on `Ecto.Multi` for transactional
  business logic with support for deferred (post-commit) side effects.

  ## Pipeline

      begin_transaction → run (inside transaction) → commit_transaction → run (post-commit) → return

  ## Usage

      defmodule MyApp.UserCreate do
        use Skeleton.Service

        defstruct params: %{}

        def perform(%__MODULE__{} = service) do
          service
          |> begin_transaction()
          |> run(:changeset, &build_changeset/1)
          |> run(:user, &insert_user/1)
          |> commit_transaction()
          |> run(&send_welcome_email/1)
          |> return(:user)
        end
      end

  ## Configuration

  Set a default repo in your application config:

      config :skeleton_service, repo: MyApp.Repo

  Or override per-service:

      use Skeleton.Service, repo: MyApp.OtherRepo
  """

  alias Skeleton.Service.TaskQueue
  alias Ecto.Multi

  require Logger

  defmacro __using__(opts \\ []) do
    alias Skeleton.Service
    alias Skeleton.Service.Config

    quote do
      @module __MODULE__
      @repo unquote(opts[:repo]) || Config.repo() || raise("Repo required")

      def begin_transaction(service), do: Service.begin_transaction(service, @module)
      def run(multi, name, fun), do: Service.run(multi, name, fun)
      def run(result, fun), do: Service.run(result, fun)
      def enqueue(result, fun), do: Service.enqueue(result, fun)

      def commit_transaction(multi, opts \\ []),
        do: Service.commit_transaction(multi, @repo, opts)

      def return(result, resource_name), do: Service.return(result, resource_name)
    end
  end

  @doc """
  Converts a service struct into an `Ecto.Multi` and starts a `TaskQueue` agent.

  Each field of the struct becomes a named step in the Multi. Internal fields
  `queue_pid` and `queue_started_here?` are added as separate steps (not from
  the struct fields) to track the task queue lifecycle.
  """
  @spec begin_transaction(struct(), module()) :: Ecto.Multi.t()
  def begin_transaction(service, _module) do
    {queue_pid, started_here?} = task_queue_start()

    multi =
      service
      |> Map.from_struct()
      |> Enum.reduce(Multi.new(), fn {key, value}, acc ->
        run(acc, key, fn _changes -> {:ok, value} end)
      end)

    multi
    |> run(:queue_pid, fn _changes -> {:ok, queue_pid} end)
    |> run(:queue_started_here?, fn _changes -> {:ok, started_here?} end)
  end

  @doc """
  Adds a named step to the `Ecto.Multi` that runs inside the database transaction.
  """
  @spec run(Ecto.Multi.t(), atom(), function()) :: Ecto.Multi.t()
  def run(multi, name, fun) do
    Multi.run(multi, name, fn _repo, service ->
      fun.(service)
    end)
  end

  @doc """
  Executes a function outside the transaction (post-commit side effect).

  Returns the result tuple unchanged. If the function raises, the error is
  logged but the successful transaction result is preserved.

  On error tuples, the function is skipped.
  """
  @spec run({:ok, map()} | {:error, atom(), any(), map()}, function()) ::
          {:ok, map()} | {:error, atom(), any(), map()}
  def run({:error, _, _, _} = error, _fun), do: error

  def run({:ok, service}, fun) do
    try do
      fun.(service)
    rescue
      e ->
        Logger.error(
          "Post-commit function failed: #{Exception.format(:error, e, __STACKTRACE__)}"
        )
    end

    {:ok, service}
  end

  @doc """
  Enqueues a function for deferred execution after a successful commit.

  On error tuples, the function is skipped.
  """
  @spec enqueue({:ok, map()} | {:error, atom(), any(), map()}, function()) ::
          {:ok, map()} | {:error, atom(), any(), map()}
  def enqueue({:ok, service}, fun) do
    TaskQueue.enqueue(fun, service)
    {:ok, service}
  end

  def enqueue({:error, _, _, _} = error, _fun), do: error

  @doc """
  Executes the `Ecto.Multi` within a database transaction.
  """
  @spec commit_transaction(Ecto.Multi.t(), module(), keyword()) ::
          {:ok, map()} | {:error, atom(), any(), map()}
  def commit_transaction(multi, repo, opts) do
    repo.transaction(multi, opts)
  end

  @doc """
  Extracts a named result from the transaction outcome.

  On success, executes enqueued tasks and returns `{:ok, resource}`.
  On failure, stops the task queue and returns `{:error, changeset}`.
  """
  @spec return({:ok, map()} | {:error, atom(), any(), map()}, atom()) ::
          {:ok, any()} | {:error, any()}
  def return({:error, failed_operation, changeset, service}, _resource_name) do
    Logger.warning("Transaction failed at operation: #{inspect(failed_operation)}")
    if service.queue_started_here?, do: TaskQueue.stop()
    {:error, changeset}
  end

  def return({:ok, service}, resource_name) do
    if service.queue_started_here?, do: TaskQueue.perform()
    {:ok, Map.get(service, resource_name)}
  end

  defp task_queue_start do
    case TaskQueue.start_link() do
      {:ok, pid} -> {pid, true}
      {:error, {_, pid}} -> {pid, false}
    end
  end
end
