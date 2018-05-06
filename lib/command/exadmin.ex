defmodule PhoenixUtils.Command.Exadmin do
  @require_lib ~S{No lib module name found. Please supply lib as part of
  optional arguments. Type --help to see the help file}

  @brunch_config_file "brunch-config.js"
  @repo_text "use Ecto.Repo, otp_app:"
  @scrivener_partial_text "use Scrivener, page_size:"
  @scrivener_text "\tuse Scrivener, page_size: 10"
  @env_import_text "# Import environment specific config."
  @static_dir "priv/static"
  @vendor_dir "static/vendor"
  @assets_dir "static/assets"
  @pipeline_text "pipeline :browser do"
  @use_exadmin_route_text "use ExAdmin.Router"
  @mix_exs_module_pattern ~r/defmodule (.+?)\.Mix.+? do/
  @mix_exs_app_pattern ~r/app: :([a-z\d_]+)?/

  @exadmin_route_scope """
  scope "/admin", ExAdmin do
    pipe_through(:browser)
    admin_routes()
  end
  """

  def run(kwargs, [path | resources]) do
    path = Path.expand(path)

    cond do
      !File.exists?(path) ->
        IO.puts("Invalid project path: '#{path}'")

      true ->
        config = Path.join(path, "config/config.exs")

        {lib, app} = get_app_lib_from_mix(path)
        lib = lib || Keyword.get(kwargs, :lib)

        if lib == nil do
          IO.puts(@require_lib)
          System.halt(1)
        end

        app = app || Keyword.get(kwargs, :app, String.downcase(lib))
        web_path = Path.join(path, "lib/#{app}_web")
        lib_path = Path.join(path, "lib/#{app}")
        exadmin_install_web_dir = Path.join(path, "web")

        options = %{
          exadmin_install_web_dir: exadmin_install_web_dir,
          app: app,
          exadmin_dir: create_or_get_exadmin_dir(web_path),
          web_module: Keyword.get(kwargs, :web, "#{lib}Web"),
          path: path,
          config: config,
          lib: lib,
          resources: resources,
          web_path: web_path,
          brunch_config_file: Path.join(path, @brunch_config_file),
          lib_path: lib_path,
          static_dir:
            Path.join(
              path,
              Keyword.get(kwargs, :static_dir, @static_dir)
            ),
          vendor_dir: Path.join(exadmin_install_web_dir, @vendor_dir),
          assets_dir: Path.join(exadmin_install_web_dir, @assets_dir)
        }

        case process_config(options) do
          :ok ->
            create_brunch_config(options)

            run_cmd(
              "mix",
              ["admin.install"],
              env: [{"MIX_ENV", "dev"}],
              cd: path
            )

            remove_brunch_config(options)
            write_repo_file(options)
            copy_web_files(options)
            write_route(options)
            write_dashboard_admin(options)
            Enum.each(resources, &write_resource_module(&1, options))
            remove_exadmin_install_web_dir(exadmin_install_web_dir)

          {:error, _reason} ->
            IO.puts("Error opening config file: '#{config}'")
        end
    end
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

  defp process_config(%{config: config} = opts) do
    IO.puts("*Reading config file #{config}")

    case File.read(config) do
      {:ok, config_text} ->
        case String.contains?(config_text, "config :ex_admin") do
          true ->
            IO.puts("*Exadmin already configured. Ignoring.")

          _ ->
            lines = String.split(config_text, "\n")

            import_config_index =
              Enum.find_index(
                lines,
                &String.contains?(&1, @env_import_text)
              )

            exadmin_config_text = gen_config_text(opts)

            new_config_text =
              List.insert_at(
                lines,
                import_config_index,
                exadmin_config_text
              )
              |> Enum.join("\n")

            IO.puts("*Writing :exadmin configuration to file #{config}")
            IO.puts("")
            IO.puts(exadmin_config_text)
            File.write!(config, new_config_text)
        end

      error ->
        error
    end
  end

  defp gen_config_text(%{lib: lib, resources: resources, web_module: web}) do
    resources =
      ["Dashboard" | resources]
      |> Enum.map(fn module -> "#{web}.ExAdmin.#{module}" end)
      |> Enum.join(", ")

    """
    config :ex_admin,
      repo: #{lib}.Repo,
      module: #{web},
      modules: [
        #{resources}
      ]
    """
  end

  defp write_route(%{web_path: web_path, web_module: web}) do
    route_file = Path.join(web_path, "router.ex")
    web_text = "use #{web}, :router"

    IO.puts("*Reading file: #{route_file}")

    case File.read(route_file) do
      {:ok, route_file_text} ->
        lines =
          String.split(route_file_text, "\n")
          |> insert_use_exadmin_route_text(web_text, route_file)

        index = get_route_insert_index(lines)

        exadmin_route_scope_text =
          lines
          |> List.insert_at(index, @exadmin_route_scope)
          |> Enum.join("\n")

        File.write!(route_file, exadmin_route_scope_text)

      _ ->
        System.halt("Unable to read file: #{route_file}. Exiting")
    end
  end

  defp insert_use_exadmin_route_text(lines, web_text, route_file) do
    case Enum.find_index(
           lines,
           &String.contains?(&1, web_text)
         ) do
      nil ->
        "Couldn't find pattern '#{web_text}' in file #{route_file}, Exiting."
        |> IO.puts()

        System.halt(0)

      index ->
        ~s(*Writing "#{@use_exadmin_route_text}" into file: #{route_file})
        |> IO.puts()

        List.insert_at(lines, index + 1, @use_exadmin_route_text)
    end
  end

  defp get_route_insert_index(lines) do
    case Enum.find_index(lines, &String.contains?(&1, @pipeline_text)) do
      nil ->
        2

      index ->
        rest = Enum.drop(lines, index + 1)

        case Enum.find_index(rest, &String.contains?(&1, "end")) do
          nil -> index
          index_ -> index + index_ + 2
        end
    end
  end

  defp create_or_get_exadmin_dir(web_path) do
    dir = Path.join(web_path, "exadmin")

    case File.exists?(dir) do
      true ->
        dir

      _ ->
        ~s(Creating directory: "#{dir}")
        File.mkdir_p!(dir)
        dir
    end
  end

  defp write_resource_module(resource, %{exadmin_dir: exadmin_dir, lib: lib, web_module: web}) do
    resource_file_name = "#{String.downcase(resource)}.ex"

    file = Path.join(exadmin_dir, resource_file_name)

    case File.exists?(file) do
      true ->
        IO.puts("*Resource #{file} already exists. Skipping.")

      _ ->
        text = """
        defmodule #{web}.ExAdmin.#{resource} do
          use ExAdmin.Register

          register_resource #{lib}.#{resource} do
          end
        end
        """

        IO.puts("*Generating resource file: #{file}")
        File.write!(file, text)
    end
  end

  defp create_brunch_config(%{brunch_config_file: file}) do
    IO.puts("*Creating brunch config file in #{file}")
    File.touch!(file)
  end

  defp remove_brunch_config(%{brunch_config_file: file}) do
    IO.puts("*Removing brunch config file")
    File.rm!(file)
  end

  defp run_cmd(command, args, opts) do
    cmd_text = [command | args] |> Enum.join(" ")
    executing_cmd_text = "*Executing command: #{cmd_text} with options:
    #{inspect(opts)}"

    IO.puts(executing_cmd_text)

    case System.cmd(command, args, opts) do
      {_stdo_text, 0} ->
        :ok

      {error_text, _} ->
        IO.puts(~s(command: "#{cmd_text}" failed to run. Exiting.))
        IO.puts(error_text)
        System.halt(1)
    end
  end

  defp write_repo_file(%{lib_path: lib_path}) do
    file = Path.join(lib_path, "repo.ex")

    IO.puts("*Reading repo.ex file: #{file}")

    case File.read(file) do
      {:ok, repo_text} ->
        lines = String.split(repo_text, "\n")

        case Enum.find_index(
               lines,
               &String.contains?(&1, @scrivener_partial_text)
             ) do
          nil ->
            case Enum.find_index(
                   lines,
                   &String.contains?(&1, @repo_text)
                 ) do
              nil ->
                ~s(Couldn't find the text: "#{@repo_text}" in #{file}. Exiting. )
                |> System.halt()

              index ->
                new_repo_text =
                  lines
                  |> List.insert_at(index + 1, @scrivener_text)
                  |> Enum.join("\n")

                ~s{*Writing scrivener config into repo file: #{file}}
                |> IO.puts()

                File.write!(file, new_repo_text)
            end

          _ ->
            ~s{*Scrivener already configured in repo. Will be skipped.}
            |> IO.puts()
        end

      _ ->
        ~s(Couldn't read file: "#{file}". Exiting)
        |> System.halt()
    end
  end

  defp copy_web_files(%{static_dir: static_dir, vendor_dir: vendor_dir, assets_dir: assets_dir}) do
    ["fonts", "images", "js", "css"]
    |> Enum.each(fn elm ->
      dest = Path.join(static_dir, elm)
      create_static_folder(dest)

      case elm == "js" || elm == "css" do
        true ->
          copy_files(vendor_dir, dest, elm)

        _ ->
          Path.join(assets_dir, elm)
          |> copy_files(dest)
      end
    end)
  end

  defp copy_files(source, dest) do
    "*Copying from #{source} to #{dest}"
    |> IO.puts()

    File.cp_r!(source, dest)
  end

  defp copy_files(source, dest, pattern) do
    source
    |> File.ls!()
    |> Enum.each(fn file ->
      case String.contains?(file, "#{pattern}") do
        true ->
          dest = Path.join(dest, file)

          source
          |> Path.join(file)
          |> copy_files(dest)

        _ ->
          :ok
      end
    end)
  end

  defp create_static_folder(dir) do
    case File.exists?(dir) do
      true ->
        :ok

      _ ->
        ~s{Creating static directory: #{dir}}
        File.mkdir_p!(dir)
    end
  end

  defp write_dashboard_admin(%{exadmin_dir: exadmin, web_module: mod}) do
    dashboard_text = """
    defmodule #{mod}.ExAdmin.Dashboard do
      use ExAdmin.Register

      register_page "Dashboard" do
        menu priority: 1, label: "Dashboard"
        content do
          div ".blank_slate_container#dashboard_default_message" do
            span ".blank_slate" do
              span "Welcome to ExAdmin. This is the default dashboard page."
              small "To add dashboard sections, checkout 'web/admin/dashboards.ex'"
            end
          end
        end
      end
    end
    """

    file = Path.join(exadmin, "dashboard.ex")

    IO.puts("*Writing dashboard admin into #{file}")
    File.write!(file, dashboard_text)
  end

  defp remove_exadmin_install_web_dir(dir) do
    IO.puts("*Removing exadmin install directory: #{dir}")
    File.rm_rf!(dir)
  end
end
