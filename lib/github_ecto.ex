defmodule GitHub.Ecto do
  alias GitHub.Ecto.SearchPath
  alias GitHub.Ecto.Request
  alias GitHub.Client

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

  def execute(_repo, _meta, prepared, [] = _params, _preprocess, opts) do
    client = opts[:client] || Client

    {_, query} = prepared

    selected_fields = select_fields(query.select.fields, query)

    path = SearchPath.build(query)
    items =
      client.get!(path)
      |> Map.fetch!("items")
      |> Enum.map(fn item -> extract_fields(item, selected_fields) end)

    {0, items}
  end

  defp extract_fields(item, selected_fields) do
    Enum.map(selected_fields, fn s ->
      if s == [] do
        item
      else
        Map.get(item, "#{s}")
      end
    end)
  end

  defp select_fields(fields, query),
    do: Enum.map(fields, &expr(&1, query))

  defp expr({{:., _, [{:&, _, [_idx]}, field]}, _, []}, _query) when is_atom(field) do
    field
  end

  defp expr({:&, [], [0]}, _query) do
    []
  end

  ## Writes

  def insert(_repo, %{model: model} = _meta, params, _autogen, _returning, _opts) do
    result = Request.build(model, params) |> Client.post!
    %{"url" => id, "number" => number, "html_url" => url} = result

    {:ok, %{id: id, number: number, url: url}}
  end

  def update(_repo, %{model: model} = _meta, params, filter, _autogen, [] = _returning, [] = _opts) do
    id = Keyword.fetch!(filter, :id)

    Request.build_patch(model, id, params) |> Client.patch!
    {:ok, %{}}
  end

  def delete(_repo, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support delete"
end

defmodule GitHub.Ecto.Request do
  def build(GitHub.Issue, params) do
    repo = Keyword.fetch!(params, :repo)
    title = Keyword.fetch!(params, :title)
    body = Keyword.fetch!(params, :body)

    path = "/repos/#{repo}/issues"
    json = Poison.encode!(%{title: title, body: body})

    {path, json}
  end

  def build_patch(GitHub.Issue, id, params) do
    "https://api.github.com" <> path = id
    json = Enum.into(params, %{}) |> Poison.encode!

    {path, json}
  end
end

defmodule GitHub.Ecto.SearchPath do
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
  defp parse_where({:==, [], [{{:., [], [{:&, [], [0]}, field]}, [ecto_type: _type], []}, value]}) do
    "#{field}:#{value}"
  end
  defp parse_where({:in, [], [%Ecto.Query.Tagged{tag: nil, type: {:in_array, {0, :labels}}, value: value}, _]}) do
    "label:#{value}"
  end
  defp parse_where({:in, [], [value, {{:., [], [{:&, [], [0]}, :labels]}, [ecto_type: :any], []}]}) do
    "label:#{value}"
  end

  defp order_by(%Ecto.Query{from: {from, _}, order_bys: [order_by]}) do
    %Ecto.Query.QueryExpr{expr: expr} = order_by
    [{order, {{:., [], [{:&, [], [0]}, sort]}, _, []}}] = expr
    {:ok, sort} = normalize_sort(from, sort)

    "sort=#{sort}&order=#{order}"
  end
  defp order_by(%Ecto.Query{order_bys: []}), do: ""
  defp order_by(_), do: raise ArgumentError, "GitHub API can only order by one field"

  defp normalize_sort("issues", :comments), do: {:ok, "comments"}
  defp normalize_sort("issues", :created_at), do: {:ok, "created"}
  defp normalize_sort("issues", :updated_at), do: {:ok, "updated"}
  defp normalize_sort("repositories", :stars), do: {:ok, "stars"}
  defp normalize_sort("repositories", :forks), do: {:ok, "forks"}
  defp normalize_sort("repositories", :updated_at), do: {:ok, "updated"}
  defp normalize_sort("users", :followers), do: {:ok, "followers"}
  defp normalize_sort("users", :public_repos), do: {:ok, "repositories"}
  defp normalize_sort("users", :created_at), do: {:ok, "joined"}
  defp normalize_sort(from, field) do
    {:error, "order_by for #{inspect(from)} and #{inspect(field)} is not supported"}
  end

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
