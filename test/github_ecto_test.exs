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

  test "create and update an issue" do
    use_cassette("create an issue") do
      issue = %GitHub.Issue{title: "Test", body: "Integration tests are a scam!", repo: "wojtekmach/github_ecto"}
      issue = TestRepo.insert!(issue)
      assert issue.title == "Test"
      assert issue.body == "Integration tests are a scam!"
      assert "https://github.com/wojtekmach/github_ecto/issues/" <> _number = issue.url

      # FIXME:
      # :timer.sleep(2000)
      q = from(i in GitHub.Issue,
               where: i.repo == "wojtekmach/github_ecto" and i.state == "open",
               order_by: i.created_at)
      TestRepo.one!(q)

      use_cassette("update an issue") do
        changeset = GitHub.Issue.changeset(issue, %{state: "closed"})
        TestRepo.update!(changeset)

        # FIXME:
        # :timer.sleep(2000)
        q = from(i in GitHub.Issue, where: i.repo == "wojtekmach/github_ecto" and i.state == "open")
        assert TestRepo.all(q) |> length == 0
      end
    end
  end

  test "search repositories" do
    use_cassette("search repositories") do
      q = from(r in GitHub.Repository,
               where: r.language == "elixir",
               order_by: [desc: r.stars])

      repositories = TestRepo.all(q)
      assert Enum.at(repositories, 0).name == "elixir"
      assert Enum.at(repositories, 1).name == "phoenix"
    end
  end

  @tag :skip
  test "create a repository" do
    use_cassette("repository creation") do
      repo = %GitHub.Repository{name: "github_ecto_test", description: "Integration tests are a scam!"}
      repo = TestRepo.insert!(repo)
      assert repo.name == "github_ecto_test"
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

    q = from i in GitHub.Issue, preload: [:user]
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
