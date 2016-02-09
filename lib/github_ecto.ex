defmodule GitHub.Issue do
  use Ecto.Schema

  schema "issues" do
    field :title, :string
    field :body, :string
    field :repo, :string
    field :url, :string
  end
end

defmodule GitHub.Ecto do
  defmodule Client do
    use GenServer

    def start_link(token) do
      GenServer.start_link(__MODULE__, token, name: __MODULE__)
    end

    ## Interface

    # Returns list of search results
    def search(path) do
      GenServer.call(__MODULE__, {:search, path})
    end

    # Returns url of the created entity
    def create(model, params) do
      GenServer.call(__MODULE__, {:create, model, params})
    end

    ## Callbacks

    def handle_call({:search, path}, _from, token) do
      url = "https://api.github.com#{path}"

      result = HTTPoison.get!(url).body
      |> Poison.decode!
      |> Map.fetch!("items")

      {:reply, result, token}
    end

    def handle_call({:create, GitHub.Issue, params}, _from, token) do
      require Logger

      repo = Keyword.fetch!(params, :repo)
      title = Keyword.fetch!(params, :title)
      body = Keyword.fetch!(params, :body)

      json = Poison.encode!(%{title: title, body: body})

      url = "https://api.github.com/repos/#{repo}/issues"
      url = if token, do: url <> "?access_token=#{token}", else: url

      result = HTTPoison.post!(url, json).body
      |> Poison.decode!

      %{"html_url" => url} = result

      {:reply, url, token}
    end
  end

  defmodule SearchPath do
    def build(query) do
      {from, _} = query.from

      str =
        [where(query), order_by(query), limit_offset(query)]
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("&")

      "/search/#{from}?#{str}"
    end

    defp where(%Ecto.Query{wheres: wheres}) do
      "q=" <> Enum.map_join(wheres, "", fn where ->
        %Ecto.Query.QueryExpr{expr: expr} = where
        parse_where(expr)
      end)
    end

    defp parse_where({:and, [], [left, right]}) do
      "#{parse_where(left)}+#{parse_where(right)}"
    end
    defp parse_where({:==, [], [_, %Ecto.Query.Tagged{tag: nil, type: {0, field}, value: value}]}) do
      "#{field}:#{value}"
    end
    defp parse_where({:==, [], [{{:., [], [{:&, [], [0]}, field]}, [ecto_type: :any], []}, value]}) do
      "#{field}:#{value}"
    end
    defp parse_where({:in, [], [%Ecto.Query.Tagged{tag: nil, type: {:in_array, {0, :labels}}, value: value}, _]}) do
      "label:#{value}"
    end
    defp parse_where({:in, [], [value, {{:., [], [{:&, [], [0]}, :labels]}, [ecto_type: :any], []}]}) do
      "label:#{value}"
    end

    defp order_by(%Ecto.Query{order_bys: [order_by]}) do
      %Ecto.Query.QueryExpr{expr: expr} = order_by
      [{order, {{:., [], [{:&, [], [0]}, sort]}, _, []}}] = expr

      "sort=#{sort}&order=#{order}"
    end
    defp order_by(%Ecto.Query{order_bys: []}), do: ""
    defp order_by(_), do: raise ArgumentError, "GitHub API can only order by one field"

    defp limit_offset(%Ecto.Query{limit: limit, offset: offset}) do
      limit = if limit do
        %Ecto.Query.QueryExpr{expr: expr} = limit
        expr
      end

      offset = if offset do
        %Ecto.Query.QueryExpr{expr: expr} = offset
        expr
      end

      case {limit, offset} do
        {nil, nil} ->
          ""

        {limit, nil} ->
          "per_page=#{limit}"

        {nil, offset} ->
          "page=2&per_page=#{offset}"

        {limit, offset} ->
          page = (offset / limit) + 1 |> round
          "page=#{page}&per_page=#{limit}"
      end
    end
  end

  ## Boilerplate

  @behaviour Ecto.Adapter

  defmacro __before_compile__(_opts), do: :ok

  def start_link(_repo, opts) do
    token = Keyword.get(opts, :token)
    Client.start_link(token)
  end

  def stop(_, _, _), do: :ok

  def load(type, data), do: Ecto.Type.load(type, data, &load/2)

  def dump(type, data), do: Ecto.Type.dump(type, data, &dump/2)

  def embed_id(_), do: ObjectID.generate

  def prepare(operation, query), do: {:nocache, {operation, query}}

  ## Reads

  def execute(_repo, _meta, prepared, [] = _params, _preprocess, [] = _opts) do
    {_, query} = prepared
    path = SearchPath.build(query)
    items = Client.search(path) |> Enum.map(fn item -> [item] end)

    {0, items}
  end

  ## Writes

  def insert(_repo, %{model: model} = _meta, params, _autogen, _returning, _opts) do
    url = Client.create(model, params)
    {:ok, %{url: url}}
  end

  def update(_repo, _, _, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support update"

  def delete(_repo, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support delete"
end
