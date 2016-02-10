defmodule GitHub.Issue do
  use Ecto.Schema

  schema "issues" do
    field :title, :string
    field :body, :string
    field :url, :string
    field :comments, :integer
    field :created_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime

    # `repo` field doesn't exist in GitHub API (there's `repository_url` though)
    # and we use it to figure out to which repo we want to add an issue
    field :repo, :string
  end
end
