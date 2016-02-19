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

  def execute(_repo, meta, prepared, [] = _params, _preprocess, opts) do
    client = opts[:client] || Client

    {_, query} = prepared

    selected_fields = select_fields(query.select.fields, query)

    path = SearchPath.build(query)
    items =
      client.get!(path)
      |> Map.fetch!("items")
      |> Enum.map(fn item ->
        extract_fields(item, selected_fields, meta.sources)
      end)

    {0, items}
  end

  defp extract_fields(nil, _, _), do: [nil]

  defp extract_fields(item, [[]], {{_, nil}}), do: [item]

  defp extract_fields(item, [[]], {{_, model}}) do
    keys =
      model.__struct__
      |> Map.keys
      |> Enum.map(&Atom.to_string/1)
    keys = keys -- ["__struct__", "__meta__"]

    map = item
      |> Map.to_list
      |> Map.new(fn {key, value} ->
        if key in keys do
          {String.to_atom(key), extract_value(model, key, value)}
        else
          {key, value}
        end
      end)

    [struct(model, map)]
  end

  defp extract_fields(item, selected_fields, _) do
    Enum.map(selected_fields, fn s ->
      Map.get(item, "#{s}")
    end)
  end

  defp select_fields(fields, query),
    do: Enum.map(fields, &expr(&1, query))

  defp extract_value(model, key, value) do
    if :"#{key}" in model.__schema__(:associations) do
      schema = model.__schema__(:association, :"#{key}").related
      extract_fields(value, [[]], {{nil, schema}}) |> Enum.at(0)
    else
      value
    end
  end

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
      %Ecto.Query.QueryExpr{expr: expr, params: params} = where
      parse_where(expr, params)
    end)
  end

  defp parse_where({:and, [], [left, right]}, params) do
    "#{parse_where(left, params)}+#{parse_where(right, params)}"
  end
  defp parse_where({:==, [], [_, %Ecto.Query.Tagged{tag: nil, type: {0, field}, value: value}]}, _) do
    "#{field}:#{value}"
  end
  defp parse_where({:==, [], [{{:., [], [{:&, [], [0]}, field]}, _, []}, value]}, params) do
    value = interpolate(value, params)
    "#{field}:#{value}"
  end
  defp parse_where({:in, [], [%Ecto.Query.Tagged{tag: nil, type: {:in_array, {0, :labels}}, value: value}, _]}, _) do
    "label:#{value}"
  end
  defp parse_where({:in, [], [value, {{:., [], [{:&, [], [0]}, :labels]}, _, []}]}, params) do
    value = interpolate(value, params)
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
      %Ecto.Query.QueryExpr{expr: expr, params: params} = limit
      interpolate(expr, params)
    end

    offset = if offset do
      %Ecto.Query.QueryExpr{expr: expr, params: params} = offset
      interpolate(expr, params)
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

  defp interpolate({:^, [], [idx]}, params) do
    Enum.at(params, idx) |> elem(0)
  end
  defp interpolate(v, _params), do: v
end
