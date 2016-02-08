defmodule GitHub.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query, only: [from: 2]

  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  test "to_url" do
    q = from r in "repositories", where: r.user == "elixir-lang"
    assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/repositories?q=user:elixir-lang"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto"
    assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/issues?q=repo:elixir-lang/ecto"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and i.state == "closed"
    assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/issues?q=repo:elixir-lang/ecto+state:closed"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: i.created
    assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/issues?q=repo:elixir-lang/ecto&sort=created&order=asc"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: [desc: i.created]
    assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/issues?q=repo:elixir-lang/ecto&sort=created&order=desc"
  end

  test "search issues" do
    use_cassette("search issues") do
      q = from i in "issues", where: i.repo == "elixir-lang/ecto" and i.state == "closed", order_by: [asc: i.created]
      assert GitHub.Ecto.to_url(q) == "https://api.github.com/search/issues?q=repo:elixir-lang/ecto+state:closed&sort=created&order=asc"

      issues = TestRepo.all(q)
      assert length(issues) == 30
      assert %{"title" => "Minor cleanup on smart escape", "state" => "closed", "url" => "https://api.github.com/repos/elixir-lang/ecto/issues/1"} = hd(issues)
    end
  end
end
