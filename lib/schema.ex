defmodule GitHub.Issue do
  use Ecto.Schema

  schema "issues" do
    field :title, :string
    field :body, :string
    field :url, :string

    # `repo` field doesn't exist in GitHub API (there's `repository_url` though)
    # and we use it to figure out to which repo we want to add an issue to
    field :repo, :string
  end
end
