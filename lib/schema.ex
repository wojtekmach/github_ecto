# TODO: In GitHub API, both User and Organization are considered
#       to be an Owner with `type`. Perhaps we should have just Owner.
defmodule GitHub.User do
  use Ecto.Schema

  @primary_key {:id, :binary_id, [autogenerate: true]} # id is the API url of the user
  schema "users" do
    field :login, :string
  end

  @required ~w(login)
  @optional ~w()

  def changeset(user, params \\ :empty) do
    user
    |> Ecto.Changeset.cast(params, @required, @optional)
  end
end

defmodule GitHub.Issue do
  use Ecto.Schema

  @primary_key {:id, :string, []} # id is the API url of the issue
  schema "issues" do
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

    embeds_one :assignee, GitHub.User
    embeds_one :user, GitHub.User

    @required ~w(title repo)
    @optional ~w(body state assignee_login)

    def changeset(issue, params \\ :empty) do
      issue
      |> Ecto.Changeset.cast(params, @required, @optional)
      |> Ecto.Changeset.cast_embed(:assignee)
    end
  end
end

defmodule GitHub.Repository do
  use Ecto.Schema

  @primary_key {:id, :string, []} # id is the API url of the repository
  schema "repositories" do
    field :created_at, Ecto.DateTime
    field :default_branch, :string
    field :description, :string
    field :fork, :boolean
    field :forks_count, :integer
    field :homepage, :string
    field :language, :string
    field :name, :string
    field :open_issues_count, :integer
    field :private, :boolean
    field :pushed_at, Ecto.DateTime
    field :stargazers_count, :integer
    field :updated_at, Ecto.DateTime
    field :url, :string
    field :watchers_count, :integer

    embeds_one :owner, GitHub.User
  end

  @required ~w(name description)
  @optional ~w()

  def changeset(repo, params \\ :empty) do
    repo
    |> Ecto.Changeset.cast(params, @required, @optional)
  end
end
