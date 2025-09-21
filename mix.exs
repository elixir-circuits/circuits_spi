defmodule Circuits.SPI.MixProject do
  use Mix.Project

  @app :circuits_spi
  @version "2.0.4"
  @description "Use SPI in Elixir"
  @source_url "https://github.com/elixir-circuits/#{@app}"

  def project do
    base = [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      description: @description,
      package: package(),
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: ["test"],
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ],
      deps: deps()
    ]

    if build_spidev?() do
      additions = [
        compilers: [:elixir_make | Mix.compilers()],
        elixirc_paths: ["backends/linux/lib"],
        test_paths: ["backends/linux/test"],
        make_makefile: "Makefile",
        make_cwd: "backends/linux",
        make_targets: ["all"],
        make_clean: ["clean"],
        aliases: [format: [&format_c/1, "format"]]
      ]

      Keyword.merge(base, additions, fn _key, value1, value2 -> value1 ++ value2 end)
    else
      base
    end |> dbg()
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs}]
  end

  def application do
    # IMPORTANT: This provides defaults at runtime and at compile-time when
    # circuits_spi is pulled in as a dependency.
    [env: [backends: default_backend(), build_spidev: false]]
  end

  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "backends/linux/c_src/*.[ch]",
        "backends/linux/lib",
        "backends/linux/Makefile",
        "lib",
        "LICENSES",
        "mix.exs",
        "NOTICE",
        "PORTING.md",
        "README.md",
        "REUSE.toml"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "GitHub" => @source_url,
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/elixir-circuits/#{@app}"
      }
    }
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp docs do
    [
      assets: %{"assets" => "assets"},
      extras: ["README.md", "PORTING.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp build_spidev?() do
    include_spidev = Application.get_env(:circuits_spi, :include_spidev)

    if include_spidev != nil do
      # If the user set :include_spidev, then use it
      include_spidev
    else
      # Otherwise, infer whether to build it based on the default_backend
      # setting. If default_backend references it, then build it. If it
      # references something else, then don't build. Default is to build.
      default_backend = Application.get_env(:circuits_spi, :backends)

      default_backend == Circuits.SPI.LinuxBackend or
        (is_tuple(default_backend) and elem(default_backend, 0) == Circuits.SPI.LinuxBackend)
    end
  end

  defp default_backend(), do: default_backend(Mix.env(), Mix.target(), build_spidev?())
  defp default_backend(:test, _target, _build_spidev?), do: Circuits.SPI.LoopBackend

  defp default_backend(_env, :host, true) do
    case :os.type() do
      {:unix, :linux} -> Circuits.SPI.LinuxBackend
      _ -> Circuits.SPI.NilBackends
    end
  end

  defp default_backend(_env, _target, false), do: Circuits.SPI.NilBackend

  # MIX_TARGET set to something besides host
  defp default_backend(env, _not_host, true) do
    # If CROSSCOMPILE is set, then the Makefile will use the cross-compiler and
    # assume a Linux/Nerves build If not, then the NIF will be build for the
    # host, so use the default host backend
    case System.fetch_env("CROSSCOMPILE") do
      {:ok, _} -> Circuits.SPI.LinuxBackend
      :error -> default_backend(env, :host, true)
    end
  end

  defp format_c([]) do
    case System.find_executable("astyle") do
      nil ->
        Mix.Shell.IO.info("Install astyle to format C code.")

      astyle ->
        System.cmd(astyle, ["-n", "backends/linux/c_src/*.c"], into: IO.stream(:stdio, :line))
    end
  end

  defp format_c(_args), do: true
end
