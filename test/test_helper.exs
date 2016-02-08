ExUnit.start()

Application.put_env(:ecto, TestRepo,
                    adapter: GitHub.Ecto)

defmodule TestRepo do
  use Ecto.Repo, otp_app: :ecto
end

{:ok, _pid} = TestRepo.start_link
