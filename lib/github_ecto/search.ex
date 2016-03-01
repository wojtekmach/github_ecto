defmodule GitHub.Ecto.Search do
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
