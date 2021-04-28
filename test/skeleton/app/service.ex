defmodule Skeleton.App.Service do
  use Skeleton.Service, otp_app: :skeleton_service

  def add_info(multi) do
    run(multi, :info, fn _service ->
      {:ok, "INFO"}
    end)
  end
end
