defmodule GitHub.User do
  use Ecto.Schema

  @primary_key {:id, :string, []} # id is the API url of the user
  schema "users" do
    field :login, :string
  end
end

defmodule GitHub.Issue do
  use Ecto.Schema

  @primary_key {:id, :string, []} # id is the API url of the issue
  schema "issues" do
    has_one :user, GitHub.User
    has_one :assignee, GitHub.User

    field :body, :string, default: ""
    field :closed_at, Ecto.DateTime
    field :comments, :integer, default: 0
    field :created_at, Ecto.DateTime
    field :labels, {:array, :string}, default: []
    field :locked, :boolean, default: false
    field :number, :integer
    field :repo, :string
    field :state, :string, default: "open"
    field :title, :string, default: ""
    field :updated_at, Ecto.DateTime
    field :url, :string

    @required ~w(title repo)
    @optional ~w(body state)

    def changeset(issue, params \\ :empty) do
      issue
      |> Ecto.Changeset.cast(params, @required, @optional)
    end
  end
end
