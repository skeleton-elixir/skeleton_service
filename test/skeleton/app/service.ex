defmodule Skeleton.App.Service do
  @moduledoc false

  import Skeleton.Service

  defmacro __using__(opts) do
    quote do
      use Skeleton.Service, unquote(opts)

      import Skeleton.App.Service
      import Ecto.{Changeset, Query}

      alias Skeleton.App.Repo
    end
  end

  def add_info(multi) do
    run(multi, :info, fn _service ->
      {:ok, "INFO"}
    end)
  end
end
