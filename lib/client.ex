defmodule GitHub.Client do
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
  def create({path, json}) do
    GenServer.call(__MODULE__, {:create, path, json})
  end

  def patch!({path, json}) do
    GenServer.call(__MODULE__, {:patch!, path, json})
  end

  ## Callbacks

  def handle_call({:search, path}, _from, token) do
    url = url(path, token)
    result = HTTPoison.get!(url).body |> Poison.decode!
    {:reply, result, token}
  end

  def handle_call({:create, path, json}, _from, token) do
    url = url(path, token)
    result = HTTPoison.post!(url, json).body |> Poison.decode!
    {:reply, result, token}
  end

  def handle_call({:patch!, path, json}, _from, token) do
    url = url(path, token)
    result = HTTPoison.patch!(url, json).body |> Poison.decode!
    {:reply, result, token}
  end

  @base_url "https://api.github.com"

  defp url(path, nil) do
    @base_url <> path
  end
  defp url(path, token) do
    c = if String.contains?(path, "?"), do: "&", else: "?"
    @base_url <> path <> c <> "access_token=" <> token
  end
end
