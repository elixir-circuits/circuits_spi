# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.AtomVMBackend do
  @moduledoc """
  Circuits.SPI backend for AtomVM's SPI hardware abstraction layer.

  AtomVM requires pin and peripheral configuration when opening an SPI bus.
  Pass named configurations to the backend with the `:buses` option:

      config :circuits_spi,
        backends: [
          {Circuits.SPI.AtomVMBackend,
           buses: %{
             "display" => [
               bus_config: [sclk: 18, mosi: 23, miso: 19, peripheral: "spi2"],
               device_config: [cs: 5]
             ]
           }}
        ]

  Options passed to `Circuits.SPI.open/2` override `:mode` and `:speed_hz`
  in the named device configuration.
  """

  @behaviour Circuits.SPI.Backend

  alias Circuits.SPI.Backend
  alias Circuits.SPI.Bus

  @device_name :circuits_spi

  defstruct [:ref, :spi_module, :config]

  @impl Backend
  def bus_names(options) do
    options
    |> Keyword.get(:buses, %{})
    |> Enum.map(fn {name, _config} -> to_string(name) end)
    |> Enum.sort()
  end

  @impl Backend
  def open(bus_name, options) do
    buses = Keyword.get(options, :buses, %{})

    with {:ok, bus_options} <- fetch_bus(buses, bus_name),
         {:ok, bus_config} <- fetch_bus_config(bus_options),
         {:ok, config} <- build_config(bus_options, options) do
      spi_module = Keyword.get(options, :spi_module, :spi)

      case spi_module.open(atomvm_config(bus_config, bus_options, config)) do
        {:error, _reason} = error ->
          error

        ref ->
          {:ok, %__MODULE__{ref: ref, spi_module: spi_module, config: config}}
      end
    end
  end

  @impl Backend
  def info(options) do
    %{
      description: "AtomVM SPI HAL",
      bus_names: bus_names(options)
    }
  end

  defp fetch_bus(buses, bus_name) do
    case Enum.find(buses, fn {name, _config} -> to_string(name) == bus_name end) do
      nil -> {:error, :not_found}
      {_name, config} -> {:ok, config}
    end
  end

  defp fetch_bus_config(bus_options) do
    case Keyword.fetch(bus_options, :bus_config) do
      {:ok, bus_config} -> {:ok, bus_config}
      :error -> {:error, {:missing_option, :bus_config}}
    end
  end

  defp build_config(bus_options, options) do
    device_options = Keyword.get(bus_options, :device_config, [])
    bits_per_word = Keyword.get(options, :bits_per_word, 8)
    lsb_first = Keyword.get(options, :lsb_first, false)
    mode = Keyword.get(options, :mode, Keyword.get(device_options, :mode, 0))

    speed_hz =
      Keyword.get(
        options,
        :speed_hz,
        Keyword.get(device_options, :clock_speed_hz, 1_000_000)
      )

    cond do
      bits_per_word != 8 ->
        {:error, {:unsupported_bits_per_word, bits_per_word}}

      lsb_first ->
        {:error, {:unsupported_option, :lsb_first}}

      mode not in 0..3 ->
        {:error, {:invalid_option, {:mode, mode}}}

      not is_integer(speed_hz) or speed_hz <= 0 ->
        {:error, {:invalid_option, {:speed_hz, speed_hz}}}

      true ->
        {:ok,
         %{
           mode: mode,
           bits_per_word: 8,
           speed_hz: speed_hz,
           delay_us: 0,
           lsb_first: false,
           sw_lsb_first: false
         }}
    end
  end

  defp atomvm_config(bus_config, bus_options, config) do
    device_options =
      bus_options
      |> Keyword.get(:device_config, [])
      |> Keyword.put(:mode, config.mode)
      |> Keyword.put(:clock_speed_hz, config.speed_hz)

    [
      bus_config: bus_config,
      device_config: [{@device_name, device_options}]
    ]
  end

  defimpl Bus do
    @max_transfer_size 4092

    @impl Bus
    def config(%Circuits.SPI.AtomVMBackend{config: config}), do: {:ok, config}

    @impl Bus
    def transfer(%Circuits.SPI.AtomVMBackend{} = bus, data) do
      transfer_chunks(bus, IO.iodata_to_binary(data), [])
    end

    @impl Bus
    def write(%Circuits.SPI.AtomVMBackend{} = bus, data) do
      write_chunks(bus, IO.iodata_to_binary(data))
    end

    @impl Bus
    def read(%Circuits.SPI.AtomVMBackend{} = bus, len) do
      read_chunks(bus, len, [])
    end

    @impl Bus
    def close(%Circuits.SPI.AtomVMBackend{} = bus) do
      bus.spi_module.close(bus.ref)
    end

    @impl Bus
    def max_transfer_size(%Circuits.SPI.AtomVMBackend{}), do: @max_transfer_size

    defp transfer_chunks(_bus, <<>>, acc) do
      {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
    end

    defp transfer_chunks(bus, data, acc) do
      {chunk, rest} = take_chunk(data)
      transaction = %{write_data: chunk}

      case bus.spi_module.write_read(bus.ref, :circuits_spi, transaction) do
        {:ok, result} -> transfer_chunks(bus, rest, [result | acc])
        {:error, _reason} = error -> error
      end
    end

    defp write_chunks(_bus, <<>>), do: :ok

    defp write_chunks(bus, data) do
      {chunk, rest} = take_chunk(data)
      transaction = %{write_data: chunk}

      case bus.spi_module.write(bus.ref, :circuits_spi, transaction) do
        :ok -> write_chunks(bus, rest)
        {:error, _reason} = error -> error
      end
    end

    defp read_chunks(_bus, 0, acc) do
      {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
    end

    defp read_chunks(bus, len, acc) do
      chunk_size = min(len, @max_transfer_size)
      transaction = %{read_bits: chunk_size * 8}

      case bus.spi_module.write_read(bus.ref, :circuits_spi, transaction) do
        {:ok, result} -> read_chunks(bus, len - chunk_size, [result | acc])
        {:error, _reason} = error -> error
      end
    end

    defp take_chunk(data) do
      chunk_size = min(byte_size(data), @max_transfer_size)
      <<chunk::binary-size(^chunk_size), rest::binary>> = data
      {chunk, rest}
    end
  end
end
