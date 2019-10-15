# VBT

A library which contains various utilities used in different VBT projects.

In addition, this library contains Credo checks which are specific to the VBT development process, and so it doesn't make sense for them to be submitted to the Credo project.

## Project scaffolding

This library also contains various mix tasks which allows you to scaffold standard configuration files for Elixir projects such as:

- Makefile
- Docker config, such as Dockerfile, docker-compose.yml, etc.
- Heroku config, such as Procfile, heroku.yml, etc.

To scaffold all supported configuration files, invoke `mix vbt.bootstrap` from the project folder. If you want to scaffold individual files (for example only Docker configuration), you can invoke individual tasks. You can find the list of available tasks by invoking `mix help --search vbt.gen`.
