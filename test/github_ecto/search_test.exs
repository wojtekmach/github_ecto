defmodule GitHub.Ecto.SearchTest do
  use ExUnit.Case, async: true
  import Ecto.Query, only: [from: 2]
  import GitHub.Ecto.Search, only: [build: 1]

  test "from" do
    q = from r in "repositories", where: r.user == "elixir-lang"
    assert build(q) == "/search/repositories?q=user:elixir-lang"

    q = from i in "issues", where: i.repo == "elixir-lang/ecto"
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto"
  end

  test "multiple fields" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and i.state == "closed"
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+state:closed"

    repo = "elixir-lang/ecto"
    state = "closed"
    q = from i in "issues", where: i.repo == ^repo and i.state == ^state
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+state:closed"
  end

  test "label" do
    q = from i in "issues", where: i.repo == "elixir-lang/ecto" and "Kind:Bug" in i.labels
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto+label:Kind:Bug"

    repo = "elixir-lang/ecto"
    label = "Kind:Bug"
    q = from i in "issues", where: i.repo == ^repo and ^label in i.labels
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

    order_by = :created_at
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", order_by: ^order_by
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&sort=created&order=asc"
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

    limit = 5
    offset = 10
    q = from i in "issues", where: i.repo == "elixir-lang/ecto", limit: ^limit, offset: ^offset
    assert build(q) == "/search/issues?q=repo:elixir-lang/ecto&page=3&per_page=5"
  end
end
