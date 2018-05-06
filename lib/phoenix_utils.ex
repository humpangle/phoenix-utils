defmodule PhoenixUtils do
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

  defp process({kwargs, ["exadmin" | args], _failures}) do
    PhoenixUtils.Command.Exadmin.run(kwargs, args)
  end

  defp process(_) do
    PhoenixUtils.Help.run()
    System.halt(1)
  end
end
