# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Mark Sebald
# SPDX-FileCopyrightText: 2021 Cocoa Xu
# SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI do
  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via a SPI bus.
  """

  alias Circuits.SPI.Bus

  @typedoc """
  Backends specify an implementation of a Circuits.SPI.Backend behaviour

  The second parameter of the Backend 2-tuple is a list of options. These are
  passed to the behaviour function call implementations.
  """
  @type backend() :: {module(), keyword()}

  @typedoc """
  SPI bus options

  Options:

  * `mode` - Set the clock polarity and phase to use:
    * Mode 0 (CPOL=0, CPHA=0) - Clock idle low/sample leading edge (default)
    * Mode 1 (CPOL=0, CPHA=1) - Clock idle low/sample trailing edge
    * Mode 2 (CPOL=1, CPHA=0) - Clock idle high/sample leading edge
    * Mode 3 (CPOL=1, CPHA=1) - Clock idle high/sample trailing edge
  * `bits_per_word` - Set the bits per word on the bus. Defaults to 8 bit words.
  * `speed_hz` - Set the bus speed. Supported speeds are device-specific. The
    default speed is 1 Mbps (1000000).
  * `delay_us` - Set the delay between transactions (10)
  * `lsb_first` - Set to `true` to send the least significant bit first rather
    than the most significant one. (false)
    The error message `unsupported mode bits 8` might be printed due to
    hardware that doesn't support the LSB-first mode, which can be ignored
    since Circuits.SPI handles it automatically.
  """
  @type spi_option() ::
          {:mode, 0..3}
          | {:bits_per_word, 8..16}
          | {:speed_hz, pos_integer()}
          | {:delay_us, non_neg_integer()}
          | {:lsb_first, boolean()}

  @typedoc """
  SPI bus options as returned by `config/1`.

  These mirror the options that can be passed to `open/2`. `:sw_lsb_first`
  is set if `:lsb_first` is true, but Circuits.SPI is doing this in software.
  """
  @type spi_option_map() :: %{
          mode: 0..3,
          bits_per_word: 8..16,
          speed_hz: pos_integer(),
          delay_us: non_neg_integer(),
          lsb_first: boolean(),
          sw_lsb_first: boolean()
        }

  @doc """
  Open a SPI bus device

  On success, `open/2` returns a reference that may be passed to
  with `transfer/2`. The device will be closed automatically when
  the reference goes out of scope.

  SPI is not a standardized interface so appropriate options will
  different from device-to-device. The defaults use here work on
  many devices.

  Parameters:
  * `bus_name` is the name of the bus (e.g., "spidev0.0"). See `bus_names/0`
  * `opts` is a keyword list to configure the bus
  """
  @spec open(binary(), [spi_option()]) :: {:ok, Bus.t()} | {:error, term()}
  def open(bus_name, options \\ []) when is_binary(bus_name) do
    try_open(backends(), bus_name, options, :not_found)
  end

  defp try_open([{module, default_options} | rest], bus_name, options, _last_reason) do
    case module.open(bus_name, Keyword.merge(default_options, options)) do
      {:ok, _} = v -> v
      {:error, reason} -> try_open(rest, bus_name, options, reason)
    end
  end

  defp try_open([], _bus_name, _options, last_reason), do: {:error, last_reason}

  @doc """
  Return the configuration for this SPI bus

  The configuration could be different that what was given to `open/2` if
  the device had to change it for it to work.
  """
  @spec config(Bus.t()) :: {:ok, spi_option_map()} | {:error, term()}
  def config(spi_bus) do
    Bus.config(spi_bus)
  end

  @doc """
  Transfer data

  Since each SPI transfer sends and receives simultaneously, the return value
  will be a binary of the same length as `data`.
  """
  @spec transfer(Bus.t(), iodata()) :: {:ok, binary()} | {:error, term()}
  def transfer(spi_bus, data) do
    Bus.transfer(spi_bus, data)
  end

  @doc """
  Transfer data and raise on error
  """
  @spec transfer!(Bus.t(), iodata()) :: binary()
  def transfer!(spi_bus, data) do
    case transfer(spi_bus, data) do
      {:error, reason} ->
        raise "SPI failure: " <> to_string(reason)

      {:ok, result} ->
        result
    end
  end

  @doc """
  Release any resources associated with the given file descriptor
  """
  @spec close(Bus.t()) :: :ok
  def close(spi_bus) do
    Bus.close(spi_bus)
  end

  @doc """
  Return a list of available SPI bus names.  If nothing is returned,
  it's possible that the kernel driver for that SPI bus is not enabled or the
  kernel's device tree is not configured. On Raspbian, run `raspi-config` and
  look in the advanced options.
  ```
  iex> Circuits.SPI.bus_names
  ["spidev0.0", "spidev0.1"]
  ```
  """
  @spec bus_names() :: [binary()]
  def bus_names() do
    backends() |> Enum.flat_map(fn {m, o} -> m.bus_names(o) end)
  end

  @doc """
  Return info about the low level SPI interface

  This may be helpful when debugging SPI issues.
  """
  @spec info(backend() | [backend()] | nil) :: [map()]
  def info(backend \\ nil)

  def info(nil), do: info(backends())
  def info(m) when is_atom(m), do: info([normalize_backend(m)])
  def info({m, o} = v) when is_atom(m) and is_list(o), do: info([v])

  def info(backends) when is_list(backends),
    do: backends |> Enum.map(&normalize_backend/1) |> Enum.map(fn {m, _o} -> m.info() end)

  defp backends() do
    Application.get_env(:circuits_spi, :backends, [])
    |> List.wrap()
    |> Enum.map(&normalize_backend/1)
  end

  defp normalize_backend(m) when is_atom(m), do: {m, []}
  defp normalize_backend({m, o} = value) when is_atom(m) and is_list(o), do: value

  @doc """
  Return the maximum transfer size in bytes

  The number of bytes that can be sent and received at a time
  may be capped by the low level SPI interface. For example,
  the Linux `spidev` driver allocates its transfer buffer at
  initialization based on the `bufsiz` parameter and rejects
  requests that won't fit.

  If you're sending large amounts of data over SPI, use this
  function to determine how to split up large messages.
  """
  @spec max_transfer_size(Bus.t() | nil) :: non_neg_integer()
  def max_transfer_size(bus \\ nil) do
    case bus do
      nil -> 0
      bus -> Bus.max_transfer_size(bus)
    end
  end
end
