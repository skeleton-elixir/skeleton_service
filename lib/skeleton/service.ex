defmodule Skeleton.Service do
  @moduledoc """
  Skeleton Service module
  """

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
      def commit_transaction(multi, opts \\ []), do: Service.commit_transaction(multi, @repo, opts)
      def return(result, resource_name), do: Service.return(result, resource_name)
    end
  end

  def begin_transaction(service) do
    service
    |> Map.from_struct()
    |> Enum.reduce(Multi.new(), fn {key, value}, acc ->
      run(acc, key, fn _changes ->
        {:ok, value}
      end)
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

  def commit_transaction(multi, repo, opts) do
    repo.transaction(multi, opts)
  end

  def return({:error, _, changeset, _}, _resource_name), do: {:error, changeset}

  def return({:ok, service}, resource_name) do
    {:ok, Map.get(service, resource_name)}
  end
end
