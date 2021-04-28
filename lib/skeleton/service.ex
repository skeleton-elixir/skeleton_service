defmodule Skeleton.Service do
  alias Ecto.Multi

  defmacro __using__(opts \\ []) do
    alias Skeleton.Service
    alias Skeleton.Service.Config

    quote do
      @module __MODULE__
      @otp_app unquote(opts[:otp_app]) || raise("Required otp_app")
      @repo unquote(opts[:repo])

      def begin_transaction(service), do: Service.begin_transaction(service)
      def run(multi, name, fun), do: Service.run(multi, name, fun)
      def run(result, fun), do: Service.run(result, fun)

      def commit_transaction(multi, repo \\ @repo) do
        Service.commit_transaction(
          multi,
          repo || Config.repo(@otp_app, @module) || raise("Required Repo")
        )
      end

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

  def commit_transaction(multi, repo) do
    repo.transaction(multi)
  end

  def return({:error, _, changeset, _}, _resource_name), do: {:error, changeset}

  def return({:ok, service}, resource_name) do
    {:ok, Map.get(service, resource_name)}
  end
end
