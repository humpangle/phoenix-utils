# PhoenixUtils

Command line utilities I use when working on
[elixir phoenix](https://hexdocs.pm/phoenix/overview.html) projects

Use it like so:
./phoenix_utils command [arguments][options]
./phoenix_utils help (for help)
./phoenix_utils --help (for help)
./phoenix_utils exadmin project_path Resource1 Resource2 --static_dir=dir

The various commands can be found in the lib/command subfolder.

# Development

run:
`mix escript.build` in development
`MIX_ENV=prod mix escript.build` for production build
