defmodule Skeleton.Service do
  @moduledoc """
  Provides a composable service pipeline built on `Ecto.Multi` for transactional
  business logic with support for deferred (post-commit) side effects.

  ## Pipeline

      validate → begin_transaction → run (inside transaction) → commit_transaction → run (post-commit) → return

  ## Usage

      defmodule MyApp.UserCreate do
        use Skeleton.Service

        defstruct params: %{}

        def perform(%__MODULE__{} = service) do
          service
          |> validate(&check_params/1)
          |> begin_transaction()
          |> run(:changeset, &build_changeset/1)
          |> run(:user, &insert_user/1)
          |> commit_transaction()
          |> run(&send_welcome_email/1)
          |> enqueue(&notify_admin/1)
          |> return(:user)
        end
      end

  ## Configuration

  Set a default repo in your application config:

      config :skeleton_service, repo: MyApp.Repo

  Or override per-service:

      use Skeleton.Service, repo: MyApp.OtherRepo

  ## Hooks

  Override `c_before_transaction/1` and `c_after_transaction/1` in your service
  module to add cross-cutting concerns (logging, audit, metrics):

      def c_before_transaction(service) do
        Logger.info("Starting transaction for \#{inspect(service)}")
        service
      end

      def c_after_transaction(result) do
        Logger.info("Transaction result: \#{inspect(result)}")
        result
      end

  ## Chained Services

  When services are chained (A calls B calls C), all enqueued tasks accumulate
  in a single process-level queue. Only the top-level service (the one that
  first called `begin_transaction`) executes the queue in its `return/2`.
  Nested services enqueue tasks but do not execute them.

  ## Telemetry

  The following telemetry events are emitted:

  - `[:skeleton, :service, :begin]` — when `begin_transaction/1` is called
  - `[:skeleton, :service, :commit]` — after `commit_transaction/1` completes
  - `[:skeleton, :service, :stop]` — when `return/2` completes

  All events include `%{module: module}` in metadata. The `:stop` event also
  includes `%{duration: duration}` in measurements and `%{status: :ok | :error}`
  in metadata.
  """

  alias Ecto.Multi

  require Logger

  @queue_key :__skeleton_service_queue__

  defmacro __using__(opts \\ []) do
    alias Skeleton.Service
    alias Skeleton.Service.Config

    quote do
      @module __MODULE__
      @repo unquote(opts[:repo]) || Config.repo() || raise("Repo required")

      def validate({:error, _} = err, _fun), do: err
      def validate(service, fun), do: Service.validate(service, fun)

      def begin_transaction({:error, _} = err), do: err

      def begin_transaction(service) do
        case c_before_transaction(service) do
          {:error, _} = err -> err
          service -> Service.begin_transaction(service, @module)
        end
      end

      def run({:error, _} = err, _name, _fun), do: err
      def run(multi, name, fun), do: Service.run(multi, name, fun)

      def run({:error, _} = err, _fun), do: err
      def run(result, fun), do: Service.run(result, fun)

      def enqueue({:error, _} = err, _fun), do: err
      def enqueue(result, fun), do: Service.enqueue(result, fun)

      def commit_transaction(multi_or_error, opts \\ [])
      def commit_transaction({:error, _} = err, _opts), do: err

      def commit_transaction(multi, opts),
        do: Service.commit_transaction(multi, @repo, opts)

      def return({:error, _} = err, _resource_name), do: err

      def return(result, resource_name) do
        result = Service.return(result, resource_name)
        c_after_transaction(result)
      end

      def c_before_transaction(service), do: service
      def c_after_transaction(result), do: result

      defoverridable c_before_transaction: 1, c_after_transaction: 1
    end
  end

  @doc """
  Validates a service struct before opening a database connection.

  Calls the given function with the service struct. The function must return
  the (possibly modified) struct on success, or `{:error, reason}` on failure.
  """
  @spec validate(struct(), function()) :: struct() | {:error, any()}
  def validate(service, fun) do
    case fun.(service) do
      {:error, _} = err -> err
      service -> service
    end
  end

  @doc """
  Converts a service struct into an `Ecto.Multi` with a single `:__input__` step
  containing all struct fields as a map, plus `:__meta__` for telemetry metadata.

  A process-level queue is initialized if not already present (for chained services).
  """
  @spec begin_transaction(struct(), module()) :: Ecto.Multi.t()
  def begin_transaction(service, module) do
    start_time = System.monotonic_time()
    queue_owner? = is_nil(Process.get(@queue_key))

    if queue_owner?, do: Process.put(@queue_key, [])

    :telemetry.execute(
      [:skeleton, :service, :begin],
      %{system_time: System.system_time()},
      %{module: module}
    )

    Multi.new()
    |> Multi.run(:__input__, fn _repo, _changes ->
      {:ok, Map.from_struct(service)}
    end)
    |> Multi.run(:__meta__, fn _repo, _changes ->
      {:ok, %{module: module, start_time: start_time, queue_owner?: queue_owner?}}
    end)
  end

  @doc """
  Adds a named step to the `Ecto.Multi` that runs inside the database transaction.

  The callback receives a map with all struct fields merged with previous step
  results (excluding internal keys).
  """
  @spec run(Ecto.Multi.t(), atom(), function()) :: Ecto.Multi.t()
  def run({:error, _} = err, _name, _fun), do: err

  def run(multi, name, fun) do
    Multi.run(multi, name, fn _repo, changes ->
      fun.(merge_input(changes))
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
      fun.(merge_input(service))
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

  Tasks accumulate in a process-level queue shared across chained services.
  Only the top-level service executes the queue. On error tuples, the function
  is skipped.
  """
  @spec enqueue({:ok, map()} | {:error, atom(), any(), map()}, function()) ::
          {:ok, map()} | {:error, atom(), any(), map()}
  def enqueue({:ok, service}, fun) do
    queue = Process.get(@queue_key, [])
    Process.put(@queue_key, [{fun, merge_input(service)} | queue])
    {:ok, service}
  end

  def enqueue({:error, _, _, _} = error, _fun), do: error

  @doc """
  Executes the `Ecto.Multi` within a database transaction.

  Emits a `[:skeleton, :service, :commit]` telemetry event with status.
  """
  @spec commit_transaction(Ecto.Multi.t(), module(), keyword()) ::
          {:ok, map()} | {:error, atom(), any(), map()}
  def commit_transaction({:error, _} = err, _repo, _opts), do: err

  def commit_transaction(multi, repo, opts) do
    result = repo.transaction(multi, opts)

    status = if match?({:ok, _}, result), do: :ok, else: :error
    meta = extract_meta(result)

    :telemetry.execute(
      [:skeleton, :service, :commit],
      %{system_time: System.system_time()},
      Map.put(meta, :status, status)
    )

    result
  end

  @doc """
  Extracts a named result from the transaction outcome.

  On success, executes enqueued tasks (if queue owner) and returns `{:ok, resource}`.
  On failure, cleans up the queue (if owner) and returns `{:error, changeset}`.
  """
  @spec return({:ok, map()} | {:error, atom(), any(), map()}, atom()) ::
          {:ok, any()} | {:error, any()}
  def return({:error, _failed_operation, changeset, changes}, _resource_name) do
    meta = Map.get(changes, :__meta__, %{})
    if Map.get(meta, :queue_owner?, false), do: Process.delete(@queue_key)
    emit_stop(meta, :error)

    {:error, changeset}
  end

  def return({:ok, service}, resource_name) do
    meta = Map.get(service, :__meta__, %{})
    if Map.get(meta, :queue_owner?, false), do: execute_queue()
    emit_stop(meta, :ok)

    {:ok, Map.get(service, resource_name)}
  end

  defp merge_input(changes) do
    input = Map.get(changes, :__input__, %{})
    rest = Map.drop(changes, [:__input__, :__meta__])
    Map.merge(input, rest)
  end

  defp execute_queue do
    queue = Process.get(@queue_key, [])
    Process.delete(@queue_key)

    queue
    |> Enum.reverse()
    |> Enum.each(fn {fun, service} ->
      try do
        fun.(service)
      rescue
        e ->
          Logger.error("Enqueued task failed: #{Exception.format(:error, e, __STACKTRACE__)}")
      end
    end)
  end

  defp emit_stop(%{module: module, start_time: start_time}, status) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:skeleton, :service, :stop],
      %{duration: duration},
      %{module: module, status: status}
    )
  end

  defp emit_stop(_meta, _status), do: :ok

  defp extract_meta({:ok, %{__meta__: meta}}), do: meta
  defp extract_meta({:error, _, _, %{__meta__: meta}}), do: meta
  defp extract_meta(_), do: %{}
end
