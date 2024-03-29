[![hexdocs.pm](https://img.shields.io/badge/docs-latest-green.svg?style=flat-square)](http://vbt-common-docs.verybigthings.com)

# VBT

A library which contains various utilities used in different VBT projects.

In addition, this library contains Credo checks which are specific to the VBT development process, and so it doesn't make sense for them to be submitted to the Credo project.

## Project scaffolding

First, make sure that your system-wide Elixir version is 1.10 or higher. If you're using asdf, check the contents of `~/.tool-versions`.

Next, install the most recent version of the scaffolder:

```
wget -q http://vbt-common-docs.verybigthings.com/vbt_new.ez -O /tmp/vbt_new.ez && \
  mix archive.install --force /tmp/vbt_new.ez
```

Run the previous command even if the scaffolder is already installed, because its code changes frequently.

After the scaffolder is installed, invoke `mix help vbt.new` for usage instructions.

The source code of the scaffolder is in the `vbt_new` folder.
