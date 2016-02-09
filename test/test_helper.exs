ExUnit.start()

Application.put_env(:my_app, TestRepo,
                    adapter: GitHub.Ecto,
                    token: System.get_env("GITHUB_TOKEN"))

defmodule TestRepo do
  use Ecto.Repo, otp_app: :my_app
end

{:ok, _pid} = TestRepo.start_link
