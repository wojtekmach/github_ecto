defmodule GitHub.Ecto.Search do
  def build(query) do
    {from, _} = query.from

    str =
      [where(query), order_by(query), limit_offset(query)]
      |> Enum.filter(&(&1 != ""))
      |> Enum.join("&")

    "/search/#{from}?#{str}"
  end

  defp where(%Ecto.Query{wheres: wheres} = query) do
    "q=" <> Enum.map_join(wheres, "", fn where ->
      %Ecto.Query.QueryExpr{expr: expr, params: params} = where
      expr(expr, params, query)
    end)
  end

  defp order_by(%Ecto.Query{order_bys: []}), do: ""
  defp order_by(%Ecto.Query{from: {from, _}, order_bys: [order_by]} = query) do
    %Ecto.Query.QueryExpr{expr: [{left, right}], params: params} = order_by
    order = expr(left, params, query)
    sort = expr(right, params, query)
    sort = normalize(from, sort)

    "sort=#{sort}&order=#{order}"
  end
  defp order_by(_), do: raise ArgumentError, "GitHub API can only order by one field"

  defp limit_offset(%Ecto.Query{limit: limit, offset: offset} = query) do
    limit = if limit do
      %Ecto.Query.QueryExpr{expr: expr, params: params} = limit
      expr(expr, params, query)
    end

    offset = if offset do
      %Ecto.Query.QueryExpr{expr: expr, params: params} = offset
      expr(expr, params, query)
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

  defp expr({:and, [], [left, right]}, params, query) do
    "#{expr(left, params, query)}+#{expr(right, params, query)}"
  end
  defp expr({:==, [], [left, right]}, params, query) do
    field = expr(left, params, query)
    value = expr(right, params, query)
    "#{field}:#{value}"
  end
  defp expr({:in, [], [left, right]}, params, query) do
    field = expr(right, params, query)
    field = normalize(query.from, field)
    value = expr(left, params, query)
    "#{field}:#{value}"
  end
  defp expr({{:., _, [{:&, _, [_idx]}, field]}, _, []}, _params, _query) do
    field
  end
  defp expr(%Ecto.Query.Tagged{type: _type, value: value}, params, query) do
    expr(value, params, query)
  end
  defp expr({:^, [], [idx]}, params, _query) do
    Enum.at(params, idx) |> elem(0)
  end
  defp expr(value, _params, _query) when is_binary(value) or is_number(value) or is_atom(value) do
    value
  end

  defp normalize({name, _schema}, field), do: normalize(name, field)
  defp normalize("issues", :labels), do: "label"
  defp normalize("issues", :comments), do: "comments"
  defp normalize("issues", :created_at), do: "created"
  defp normalize("issues", :updated_at), do: "updated"
  defp normalize("repositories", :stars), do: "stars"
  defp normalize("repositories", :forks), do: "forks"
  defp normalize("repositories", :updated_at), do: "updated"
  defp normalize("users", :followers), do: "followers"
  defp normalize("users", :public_repos), do: "repositories"
  defp normalize("users", :created_at), do: "joined"
end
