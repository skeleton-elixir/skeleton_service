defmodule Skeleton.Service do
  alias Ecto.Multi

  defmacro __using__(opts \\ []) do
    alias Skeleton.Service, as: Serv

    quote do
      @repo unquote(opts[:repo])

      def begin_transaction(service), do: Serv.begin_transaction(service)
      def run(multi, name, fun), do: Serv.run(multi, name, fun)
      def run(result, fun), do: Serv.run(result, fun)
      def commit_transaction(multi), do: Serv.commit_transaction(multi, @repo)
      def return(result, resource_name), do: Serv.return(result, resource_name)
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
    Multi.run(multi, name, fn _repo, service -> fun.(service) end)
  end

  def run({:error, _, _, _} = error, _fun), do: error

  def run({:ok, service}, fun) do
    fun.(service)
    {:ok, service}
  end

  def spawn_run({:error, _, _, _} = error, _fun), do: error

  def commit_transaction(multi, repo) do
    repo.transaction(multi)
  end

  def return({:error, _, changeset, _}, _resource_name), do: {:error, changeset}

  def return({:ok, service}, resource_name) do
    {:ok, Map.get(service, resource_name)}
  end
end