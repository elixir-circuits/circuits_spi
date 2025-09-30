defmodule Circuits.SPI.LinuxMixProject do
  use Mix.Project

  @app :circuits_spi_linux
  @version "2.0.4"
  @description "CircuitsSPI Linux Backend"
  @source_url "https://github.com/elixir-circuits/#{@app}"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      description: @description,
      package: package(),
      source_url: @source_url,
      compilers: [:elixir_make | Mix.compilers()],
      elixirc_paths: elixirc_paths(Mix.env()),
      make_makefile: "Makefile",
      make_targets: ["all"],
      make_clean: ["clean"],
      aliases: [format: [&format_c/1, "format"]],
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ],
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs}]
  end

  def application do
    []
  end

  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "c_src/*.[ch]",
        "lib",
        "LICENSES",
        "Makefile",
        "mix.exs",
        "NOTICE",
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
      {:circuits_spi, "~> 2.0", path: "../.."},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp docs do
    [
      assets: %{"assets" => "assets"},
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp format_c([]) do
    case System.find_executable("astyle") do
      nil ->
        Mix.Shell.IO.info("Install astyle to format C code.")

      astyle ->
        System.cmd(astyle, ["-n", "c_src/*.c"], into: IO.stream(:stdio, :line))
    end
  end

  defp format_c(_args), do: true
end
