# GitHub.Ecto

## Example

```elixir
# Paste below to iex

# 0. Install this application (see instructions at the end of the README)

# 1. Define `Repo` (or `GitHub` or whatever):
defmodule Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: GitHub.Ecto
end

# 2. Configure this application. Currently the application has no configuration, however this step is still required. In a real project you'd configure it in config/*.exs as every other adapter.
Application.put_env(:my_app, Repo, [])

# 3. Start the Repo process. In a real project you'd put the Repo module in your project's supervision tree:
{:ok, _pid} = Repo.start_link

# 4. Import Ecto.Query
import Ecto.Query, only: [from: 2]

# 5. List all open feature requests on Ecto:
Repo.all(from i in "issues",
       where: i.repo == "elixir-lang/ecto" and
              i.state == "open" and
              "Kind:Feature" in i.labels)
# => [%{"title" => "...", "state" => "...", "url" => "...", ...}, ...]
```

See more examples of usage in [tests](test/github_ecto_test.exs). Also see the [Ecto API](http://hexdocs.pm/ecto/Ecto.html) and [GitHub API](https://developer.github.com/v3).

## Why?

First of all this library is in a very early stage and isn't suitable for production use.
Second of all, it may never be suitable for production use :-)
There're already existing wrappers for GitHub API and, honestly, it may or may not be such a good
idea to wrap it with Ecto. The primary goal of this project is for me to learn more about Ecto and it's internals and secondarily to build something useful :-)

## Installation

  1. Add `github_ecto` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:github_ecto, github: "wojtekmach/github_ecto"}]
    end
    ```

  2. Ensure `github_ecto` is started before your application:

    ```elixir
    def application do
      [applications: [:logger, :github_ecto, :ecto]]
    end
    ```

## License

The MIT License (MIT)

Copyright (c) 2016 Wojciech Mach

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
