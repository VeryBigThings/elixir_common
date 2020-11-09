# Used by "mix format"
[
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:stream_data, :ecto, :ecto_sql, :absinthe, :plug, :phoenix],
  locals_without_parens: [gen: 1, gen: 2]
]
