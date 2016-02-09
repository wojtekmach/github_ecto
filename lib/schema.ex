defmodule GitHub.Issue do
  use Ecto.Schema

  schema "issues" do
    field :title, :string
    field :body, :string
    field :repo, :string
    field :url, :string
  end
end
