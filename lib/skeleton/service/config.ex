defmodule Skeleton.Service.Config do
  def repo(otp_app, module), do: config(otp_app, module, :repo)

  def config(otp_app, module, key, default \\ nil) do
    Application.get_env(otp_app, module)[key] || default
  end
end
