defmodule GitHub.EctoIntegrationTest do
  use ExUnit.Case, async: false
  import Ecto.Query, only: [from: 2]

  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.filter_sensitive_data("access_token=.*", "access_token=[FILTERED]")
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  test "issues: search" do
    use_cassette("issues_search") do
      q = from(i in "issues",
               where: i.repo == "elixir-lang/ecto" and i.state == "closed" and "Kind:Bug" in i.labels,
               order_by: [asc: i.created_at])

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

  test "issues: create and update" do
    use_cassette("issues_create_update") do
      params = %{
        title: "Test",
        body: "Integration tests are a scam!",
        repo: "wojtekmach/github_ecto_test",
        assignee: %{login: "wojtekmach"},
      }
      issue = GitHub.Issue.changeset(%GitHub.Issue{}, params)
      issue = TestRepo.insert!(issue)
      assert issue.title == "Test"
      assert issue.body == "Integration tests are a scam!"
      assert "https://github.com/wojtekmach/github_ecto_test/issues/" <> _number = issue.url
      assert issue.state == "open"
      assert issue.user.login == "wojtekmach"
      assert issue.assignee.login == "wojtekmach"

      changeset = GitHub.Issue.changeset(issue, %{state: "closed"})
      TestRepo.update!(changeset)
    end
  end

  test "repositories: search" do
    use_cassette("repositories_search") do
      q = from(r in GitHub.Repository,
               where: r.language == "elixir",
               order_by: [desc: r.stars])

      repositories = TestRepo.all(q)
      assert Enum.at(repositories, 0).name == "elixir"
      assert Enum.at(repositories, 1).name == "phoenix"
    end
  end

  test "repositories: create" do
    use_cassette("repositories_create") do
      params = %{name: "github_ecto_test_create",
                 description: "Integration tests are a scam!"}
      repo = GitHub.Repository.changeset(%GitHub.Repository{}, params)
      repo = TestRepo.insert!(repo)
      assert repo.name == "github_ecto_test_create"
      assert repo.private == false
      assert repo.description == "Integration tests are a scam!"
      assert repo.owner.login == "wojtekmach"
    end
  end
end

defmodule GitHub.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  defmodule FakeClient do
    def get!(_path) do
      items = [
        build(%{number: 1, title: "Issue 1"}),
        build(%{number: 2, title: "Issue 2"}),
      ]

      %{"items" => items}
    end

    defp build(params) do
      Map.merge(defaults("issues"), params)
      |> Enum.into(%{}, fn {field, value} -> {Atom.to_string(field), value} end)
      |> Poison.encode! |> Poison.decode!
    end

    defp defaults("issues") do
      %{
        id: nil,
        body: "",
        closed_at: nil,
        comments: 0,
        created_at: nil,
        labels: [],
        locked: false,
        number: 222,
        repo: nil,
        state: "open",
        title: "",
        url: nil,
        updated_at: nil,
        user: defaults("user"),
        assignee: nil,
      }
    end
    defp defaults("user") do
      %{
        login: "alice",
      }
    end
  end

  test "select: all fields" do
    q = from i in "issues"
    assert [
      %{"number" => 1, "title" => "Issue 1", "user" => %{"login" => "alice"}},
      %{"number" => 2, "title" => "Issue 2", "user" => %{"login" => "alice"}},
    ] = TestRepo.all(q, client: FakeClient)

    q = from i in GitHub.Issue
    assert [
      %GitHub.Issue{number: 1, title: "Issue 1", user: %GitHub.User{login: "alice"}},
      %GitHub.Issue{number: 2, title: "Issue 2", user: %GitHub.User{login: "alice"}},
    ] = TestRepo.all(q, client: FakeClient)
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
