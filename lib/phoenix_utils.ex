defmodule PhoenixUtils do
  @require_lib ~S{No lib module name found. Please supply lib as part of
  optional arguments. Type --help to see the help file}

  @mix_exs_module_pattern ~r/defmodule (.+?)\.Mix.+? do/
  @mix_exs_app_pattern ~r/app: :([a-z\d_]+)?/

  def main(args) do
    args
    |> OptionParser.parse()
    |> process()
  end

  # help command
  defp process({_kwargs, ["help"], _}) do
    PhoenixUtils.Help.run()
  end

  # help command
  defp process({[help: _], _args, _}) do
    PhoenixUtils.Help.run()
  end

  defp process({kwargs, [command | [path | args]], _failures}) do
    path = Path.expand(path)

    case File.exists?(path) do
      true ->
        {lib, app} = get_app_lib_from_mix(path)
        lib = lib || Keyword.get(kwargs, :lib)

        if lib == nil do
          IO.puts(@require_lib)
          System.halt(1)
        end

        app = app || Keyword.get(kwargs, :app, String.downcase(lib))
        web_path = Path.join(path, "lib/#{app}_web")
        lib_path = Path.join(path, "lib/#{app}")

        kwargs =
          [
            path: path,
            lib: lib,
            lib_path: lib_path,
            app: app,
            web_path: web_path
          ]
          |> Enum.concat(kwargs)

        process(command, kwargs, args)

      _ ->
        IO.puts(["Invalid project path: '", path, "'"])
        System.halt(1)
    end
  end

  defp process(_) do
    PhoenixUtils.Help.run()
    System.halt(1)
  end

  defp process("exadmin", kwargs, args) do
    PhoenixUtils.Command.Exadmin.run(kwargs, args)
  end

  defp get_app_lib_from_mix(path) do
    IO.puts("*Reading mix file to retrieve lib module and app name")

    case Path.join(path, "mix.exs") |> File.read() do
      {:ok, mix_text} ->
        lib =
          case Regex.run(@mix_exs_module_pattern, mix_text) do
            [_, lib] ->
              lib

            _ ->
              nil
          end

        app =
          case Regex.run(@mix_exs_app_pattern, mix_text) do
            [_, app] ->
              app

            _ ->
              nil
          end

        {lib, app}

      _ ->
        IO.puts("No mix file found in project root. Exiting.")
    end
  end
end
