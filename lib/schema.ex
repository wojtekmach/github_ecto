defmodule GitHub.Issue do
  use Ecto.Schema

  @primary_key {:id, :string, []} # id is the API url of the issue
  schema "issues" do
    field :number, :integer
    field :title, :string
    field :body, :string
    field :state, :string
    field :url, :string
    field :comments, :integer
    field :created_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime

    # `repo` field doesn't exist in GitHub API (there's `repository_url` though)
    # and we use it to figure out to which repo we want to add an issue
    field :repo, :string

    @required ~w(title repo)
    @optional ~w(body state)

    def changeset(issue, params \\ :empty) do
      issue
      |> Ecto.Changeset.cast(params, @required, @optional)
    end
  end
end
