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
    end
    |> dbg()
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs}]
  end

  def application do
    # IMPORTANT: This provides defaults at runtime and at compile-time when
    # circuits_spi is pulled in as a dependency.
    [env: [backends: default_backends(), build_spidev: false]]
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
    # Infer whether to build it based on the backends
    # setting. If backends references it, then build it. If it
    # references something else, then don't build. Default is to build.
    backends = Application.get_env(:circuits_spi, :backends, default_backends())

    Enum.find(backends, &linux_backend?/1) != nil
  end

  defp linux_backend?(Circuits.SPI.LinuxBackend), do: true
  defp linux_backend?({Circuits.SPI.LinuxBackend, _}), do: true
  defp linux_backend?(_other), do: false

  defp default_backends() do
    [] |> maybe_add_test_backends(Mix.env()) |> maybe_add_linux_backend(Mix.target(), :os.type())
  end

  defp maybe_add_test_backends(backends, :test), do: [Circuits.SPI.LoopBackend | backends]
  defp maybe_add_test_backends(backends, _other), do: backends

  defp maybe_add_linux_backend(backends, :host, {:unix, :linux}),
    do: [Circuits.SPI.LinuxBackend | backends]

  defp maybe_add_linux_backend(backends, :host, _other), do: backends

  defp maybe_add_linux_backend(backends, _not_host, os) do
    # If CROSSCOMPILE is set, then the Makefile will use the cross-compiler and
    # assume a Linux/Nerves build If not, then the NIF will be build for the
    # host, so use the default host backend
    case System.fetch_env("CROSSCOMPILE") do
      {:ok, _} -> [Circuits.SPI.LinuxBackend | backends]
      :error -> maybe_add_linux_backend(backends, :host, os)
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
