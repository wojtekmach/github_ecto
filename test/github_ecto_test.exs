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

      assert GitHub.Ecto.SearchPath.build(q) ==
        "/search/issues?q=repo:elixir-lang/ecto+state:closed+label:Kind:Bug&sort=created&order=asc"

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
      TestRepo.one!(from i in GitHub.Issue, where: i.repo == "wojtekmach/github_ecto" and i.state == "open")

      use_cassette("update an issue") do
        changeset = GitHub.Issue.changeset(issue, %{"state" => "closed"})
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
        %{"title" => "Issue 1", "number" => 1},
        %{"title" => "Issue 2", "number" => 2},
      ]

      %{"items" => items}
    end
  end

  test "select: all fields" do
    q = from i in "issues"
    assert TestRepo.all(q, client: FakeClient) ==
      [%{"number" => 1, "title" => "Issue 1"}, %{"number" => 2, "title" => "Issue 2"}]

    q = from i in "issues", select: i
    assert TestRepo.all(q, client: FakeClient) ==
      [%{"number" => 1, "title" => "Issue 1"}, %{"number" => 2, "title" => "Issue 2"}]
  end

  test "select: some fields" do
    q = from i in "issues", select: i.title
    assert TestRepo.all(q, client: FakeClient) ==
      ["Issue 1", "Issue 2"]

    q = from i in "issues", select: {i.number, i.title}
    assert TestRepo.all(q, client: FakeClient) ==
      [{1, "Issue 1"}, {2, "Issue 2"}]
  end
end

defmodule GitHub.Ecto.SearchPathTest do
  use ExUnit.Case, async: true
  import Ecto.Query, only: [from: 2]
  import GitHub.Ecto.SearchPath, only: [build: 1]

  test "from" do
    q = from r in "repositories", where: r.user == "elixir-lang"
    assert build(q) == "/search/repositories?q=user:elixir-lang"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto"
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto"
  end

  @tag :skip
  test "pin variables" do
    repo = "elixir-lang/ecto"
    q = from i in "issues", where: i.repo == ^repo
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto"
  end

  test "multiple fields" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and i.state == "closed"
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+state:closed"
  end

  test "label" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and "Kind:Bug" in i.labels
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+label:Kind:Bug"
  end

  test "multiple labels" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and "Kind:Bug" in i.labels and "Level:Advanced" in i.labels
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+label:Kind:Bug+label:Level:Advanced"
  end

  test "order_by" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: i.created_at
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&sort=created&order=asc"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: [desc: i.created_at]
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&sort=created&order=desc"
  end

  test "limit" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", limit: 10
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&per_page=10"
  end

  test "offset" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", offset: 10
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&page=2&per_page=10"
  end

  test "limit and offset" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", limit: 5, offset: 10
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&page=3&per_page=5"
  end
end
