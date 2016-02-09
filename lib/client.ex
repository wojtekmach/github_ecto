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

  ## Callbacks

  def handle_call({:search, path}, _from, token) do
    url = "https://api.github.com#{path}"

    result = HTTPoison.get!(url).body
    |> Poison.decode!
    |> Map.fetch!("items")

    {:reply, result, token}
  end

  def handle_call({:create, path, json}, _from, token) do
    url = "https://api.github.com#{path}"
    url = if token, do: url <> "?access_token=#{token}", else: url

    result = HTTPoison.post!(url, json).body |> Poison.decode!

    %{"html_url" => url} = result

    {:reply, url, token}
  end
end
