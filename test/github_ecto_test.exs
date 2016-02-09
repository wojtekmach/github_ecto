defmodule GitHub.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query, only: [from: 2]

  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  test "search issues" do
    use_cassette("search issues") do
      q = from i in "issues",
        where: i.repo == "elixir-lang/ecto" and i.state == "closed",
        order_by: [asc: i.created]

      assert GitHub.Ecto.SearchPath.build(q) == "/search/issues?q=repo:elixir-lang/ecto+state:closed&sort=created&order=asc"

      issues = TestRepo.all(q)
      assert length(issues) == 30
      assert %{"title" => "Minor cleanup on smart escape", "state" => "closed", "url" => "https://api.github.com/repos/elixir-lang/ecto/issues/1"} = hd(issues)
    end
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

  test "multiple fields" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and i.state == "closed"
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+state:closed"
  end

  test "order_by" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: i.created
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&sort=created&order=asc"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: [desc: i.created]
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
