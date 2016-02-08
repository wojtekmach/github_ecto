defmodule GitHub.Ecto do
  ## Boilerplate

  @behaviour Ecto.Adapter

  defmacro __before_compile__(_opts), do: :ok

  def start_link(_repo, _opts) do
    Task.start_link(fn -> :timer.sleep(:infinity) end)
  end

  def stop(_, _, _), do: :ok

  def load(type, data), do: Ecto.Type.load(type, data, &load/2)

  def dump(type, data), do: Ecto.Type.dump(type, data, &dump/2)

  def embed_id(_), do: ObjectID.generate

  def prepare(operation, query), do: {:nocache, {operation, query}}

  ## Reads

  def execute(_repo, _meta, prepared, [] = _params, _preprocess, [] = _opts) do
    {_, query} = prepared
    url = to_url(query)
    items = make_request(url) |> Enum.map(fn item -> [item] end)

    {0, items}
  end

  defp make_request(url) do
    HTTPoison.get!(url).body
    |> Poison.decode!
    |> Map.fetch!("items")
  end

  def to_url(query) do
    {from, _} = query.from

    str =
      [where(query), order_by(query), limit_offset(query)]
      |> Enum.filter(&(&1 != ""))
      |> Enum.join("&")

    "https://api.github.com/search/#{from}?#{str}"
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

  ## Writes

  def insert(_repo, _, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support insert"

  def update(_repo, _, _, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support update"

  def delete(_repo, _, _, _, _), do: raise ArgumentError, "GitHub adapter doesn't yet support delete"
end
