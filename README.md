# VBT

A library which contains various utilities used in different VBT projects.

In addition, this library contains Credo checks which are specific to the VBT development process, and so it doesn't make sense for them to be submitted to the Credo project.

# Skafolder

A library for generating standard configuration files for Elixir projects such as:
- Makefile
- Docker config, such as Dockerfile, docker-compose.yml, etc.
- Heroku config, such as Procfile, heroku.yml, etc.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `scaffolder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:skafolder, "~> 0.1.0"}
  ]
end
```

## Usage

Generate a Makefile, without the Docker related tasks purposed for Heroku deployment

```bash
mix vbt.gen.makefile --no-docker --cloud heroku
```

Generate a Makefile, with Docker tasks included and purposed for AWS deployment

```bash
mix vbt.gen.makefile --cloud aws
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/skafolder](https://hexdocs.pm/skafolder).

