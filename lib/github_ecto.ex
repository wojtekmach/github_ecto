defmodule GitHub.Ecto do
  alias GitHub.Ecto.Search
  alias GitHub.Ecto.Request
  alias GitHub.Client

  ## Boilerplate

  @behaviour Ecto.Adapter

  defmacro __before_compile__(_opts), do: :ok

  def application do
    :github_acto
  end

  def child_spec(_repo, opts) do
    token = Keyword.get(opts, :token)
    Supervisor.Spec.worker(Client, [token])
  end

  def stop(_, _, _), do: :ok

  def loaders(_primitive, type), do: [type]

  def dumpers(_primitive, type), do: [type]

  def embed_id(_), do: ObjectID.generate

  def prepare(operation, query), do: {:nocache, {operation, query}}

  def autogenerate(_), do: raise "Not supported by adapter"

  ## Reads

  def execute(_repo, meta, prepared, [] = _params, _preprocess, opts) do
    client = opts[:client] || Client

    {_, {:all, query}} = prepared

    selected_fields = select_fields(query.select.fields, query)

    path = Search.build(query)
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

  defp expr({:&, [], [0, _, _]}, _query) do
    []
  end

  ## Writes

  def insert(_repo, %{schema: schema} = _meta, params, _autogen, _opts) do
    result = Request.build(schema, params) |> Client.post!
    %{"url" => id, "number" => number, "html_url" => url} = result

    {:ok, %{id: id, number: number, url: url}}
  end

  def insert_all(_, _, _, _, _, _), do: raise "Not supported by adapter"

  def delete(_, _, _, _), do: raise "Not supported by adapter"

  def update(_repo, %{schema: schema} = _meta, params, filter, _autogen, _opts) do
    id = Keyword.fetch!(filter, :id)

    Request.build_patch(schema, id, params) |> Client.patch!
    {:ok, %{}}
  end
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
