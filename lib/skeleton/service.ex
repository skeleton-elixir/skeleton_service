defmodule Skeleton.Service do
  @moduledoc """
  Skeleton Service module
  """

  alias Skeleton.Service.Server
  alias Ecto.Multi

  defmacro __using__(opts \\ []) do
    alias Skeleton.Service
    alias Skeleton.Service.Config

    quote do
      @module __MODULE__
      @repo unquote(opts[:repo]) || Config.repo() || raise("Repo required")

      def begin_transaction(service), do: Service.begin_transaction(service)
      def run(multi, name, fun), do: Service.run(multi, name, fun)
      def run(result, fun), do: Service.run(result, fun)
      def enqueue(result, fun), do: Service.enqueue(result, fun)

      def commit_transaction(multi, opts \\ []),
        do: Service.commit_transaction(multi, @repo, opts)

      def return(result, resource_name), do: Service.return(result, resource_name)
    end
  end

  def begin_transaction(service) do
    {queue_pid, started_here?} =
      case Server.start_link(self()) do
        {:ok, pid} -> {pid, true}
        {:error, {_, pid}} -> {pid, false}
      end

    service
    |> Map.from_struct()
    |> Map.put(:queue_pid, queue_pid)
    |> Map.put(:queue_started_here?, started_here?)
    |> Enum.reduce(Multi.new(), fn {key, value}, acc ->
      run(acc, key, fn _changes -> {:ok, value} end)
    end)
  end

  def run(multi, name, fun) do
    Multi.run(multi, name, fn _repo, service ->
      fun.(service)
    end)
  end

  def run({:error, _, _, _} = error, _fun), do: error

  def run({:ok, service}, fun) do
    fun.(service)
    {:ok, service}
  end

  def enqueue({:ok, service}, fun) do
    Server.enqueue_task(self(), fun.(service))
    {:ok, service}
  end

  def commit_transaction(multi, repo, opts) do
    repo.transaction(multi, opts)
  end

  def return({:error, _, changeset, _service}, _resource_name) do
    {:error, changeset}
  end

  def return({:ok, service}, resource_name) do
    if service.queue_started_here?, do: Server.perform(self())
    {:ok, Map.get(service, resource_name)}
  end
end
