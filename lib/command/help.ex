defmodule PhoenixUtils.Help do
  @help_text """
  Usage:
  ./phoenix_utils command [arguments] [options]
  ./phoenix_utils help (for help)
  ./phoenix_utils --help (for help)

  For windows user:
  escript phoenix_utils [options]
  escript phoenix_utils help
  escript phoenix_utils --help

  Note: any argument beginning with * must be specified

  Commands:
    help        -Prints this help text and exit
    exadmin     -Utility for configuring exadmin. It will update your
                 config/config.exs with the :exadmin app configuration,
                 repo.ex with the :scrivener paging configuration,
                 copy static files to your static directory, configure the
                 dashboard resource and write any resources you specify. This
                 command takes one compulsory positional argument: the project
                 path.
      You will you it like so:
      ./phoenix_utils exadmin project_path Resource1 Resource2 --static_dir=dir

      Arguments for exadmin:
        *project_path  -The absolute or relative filesystem path to the mix
                      project
        resources     -The schema we want to configure for exadmin e.g User,
                        Post

      options for exadmin:
        lib           -The root lib module. Defaults to
                      {lib_module}.MixProject|MixFile.
        app           -This is your app name under
                      {lib_module}.MixProject.project/1 in mix.exs file.
                      Defaults to String.downcase(lib_module)
        web           -The web module. Defaults to {lib_module}Web
        static_dir    -The directory from which static files are served
                      defaults to {project_path}/priv/static
  """

  def run() do
    IO.puts(@help_text)
  end
end
