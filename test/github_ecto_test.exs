defmodule GitHub.EctoIntegrationTest do
  use ExUnit.Case, async: false
  import Ecto.Query, only: [from: 2]

  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.filter_sensitive_data("access_token=.*", "access_token=[FILTERED]")
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  test "search issues" do
    use_cassette("search issues") do
      q = from i in "issues",
        where: i.repo == "elixir-lang/ecto" and i.state == "closed" and "Kind:Bug" in i.labels,
        order_by: [asc: i.created_at]

      issues = TestRepo.all(q)
      assert length(issues) == 30
      assert %{
        "title" => "Support div and rem, discuss what should happen with /",
        "state" => "closed",
        "url" => "https://api.github.com/repos/elixir-lang/ecto/issues/43",
        "labels" => [%{"name" => "Kind:Bug"}, %{"name" => "Note:Discussion"}],
      } = hd(issues)
    end
  end

  test "create and update an issue" do
    use_cassette("create an issue") do
      issue = %GitHub.Issue{title: "Test", body: "Integration tests are a scam!", repo: "wojtekmach/github_ecto"}
      issue = TestRepo.insert!(issue)
      assert issue.title == "Test"
      assert issue.body == "Integration tests are a scam!"
      assert "https://github.com/wojtekmach/github_ecto/issues/" <> _number = issue.url

      # FIXME:
      # :timer.sleep(2000)
      TestRepo.first!(from i in GitHub.Issue,
                    where: i.repo == "wojtekmach/github_ecto" and i.state == "open",
                 order_by: i.created_at)

      use_cassette("update an issue") do
        changeset = GitHub.Issue.changeset(issue, %{state: "closed"})
        TestRepo.update!(changeset)

        # FIXME:
        # :timer.sleep(2000)
        assert TestRepo.all(from i in GitHub.Issue, where: i.repo == "wojtekmach/github_ecto" and i.state == "open") |> length == 0
      end
    end
  end
end

defmodule GitHub.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query, only: [from: 1, from: 2]

  defmodule FakeClient do
    def get!(_path) do
      items = [
        %{"title" => "Issue 1", "number" => 1, "user" => %{"login" => "alice"}},
        %{"title" => "Issue 2", "number" => 2, "user" => %{"login" => "bob"}},
      ]

      %{"items" => items}
    end
  end

  test "select: all fields" do
    q = from i in "issues"
    assert TestRepo.all(q, client: FakeClient) == [
      %{"number" => 1, "title" => "Issue 1", "user" => %{"login" => "alice"}},
      %{"number" => 2, "title" => "Issue 2", "user" => %{"login" => "bob"}},
    ]

    q = from i in GitHub.Issue
    assert TestRepo.all(q, client: FakeClient) == [
      %GitHub.Issue{number: 1, title: "Issue 1", user: %GitHub.User{login: "alice"}},
      %GitHub.Issue{number: 2, title: "Issue 2", user: %GitHub.User{login: "bob"}},
    ]
  end

  test "select: some fields" do
    q = from i in "issues", select: i.title
    assert TestRepo.all(q, client: FakeClient) ==
      ["Issue 1", "Issue 2"]

    q = from i in "issues", select: {i.number, i.title}
    assert TestRepo.all(q, client: FakeClient) ==
      [{1, "Issue 1"}, {2, "Issue 2"}]

    q = from i in GitHub.Issue, select: {i.number, i.title}
    assert TestRepo.all(q, client: FakeClient) ==
      [{1, "Issue 1"}, {2, "Issue 2"}]
  end
end

