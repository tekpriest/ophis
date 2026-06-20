# Used by "mix format"
[
  import_deps: [:ecto, :ecto_sql, :open_api_spex, :phoenix],
  
  subdirectories: ["priv/*/migrations"],
  
  plugins: [],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  line_length: 120
]
