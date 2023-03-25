# SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI do
  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via a SPI bus.
  """

  alias Circuits.SPI.Nif

  @typedoc """
  SPI bus options. See `open/2`.
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

  @typedoc """
  SPI bus

  Call `open/2` to obtain an SPI bus reference.
  """
  @type spi_bus() :: reference()

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

  SPI bus options include:
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
  """
  @spec open(binary() | charlist(), [spi_option()]) :: {:ok, spi_bus()} | {:error, term()}
  def open(bus_name, opts \\ []) do
    mode = Keyword.get(opts, :mode, 0)
    bits_per_word = Keyword.get(opts, :bits_per_word, 8)
    speed_hz = Keyword.get(opts, :speed_hz, 1_000_000)
    delay_us = Keyword.get(opts, :delay_us, 10)
    lsb_first = if Keyword.get(opts, :lsb_first), do: 1, else: 0

    Nif.open(to_string(bus_name), mode, bits_per_word, speed_hz, delay_us, lsb_first)
  end

  @doc """
  Return the configuration for this SPI bus

  The configuration could be different that what was given to `open/2` if
  the device had to change it for it to work.
  """
  @spec config(spi_bus()) :: {:ok, spi_option_map()} | {:error, term()}
  def config(spi_bus) do
    with {:ok, config} <- Nif.config(spi_bus) do
      {:ok, %{config | lsb_first: config.lsb_first != 0, sw_lsb_first: config.sw_lsb_first != 0}}
    end
  end

  @doc """
  Transfer data

  Since each SPI transfer sends and receives simultaneously, the return value
  will be a binary of the same length as `data`.
  """
  @spec transfer(spi_bus(), iodata()) :: {:ok, binary()} | {:error, term()}
  def transfer(spi_bus, data) do
    Nif.transfer(spi_bus, data)
  end

  @doc """
  Transfer data and raise on error
  """
  @spec transfer!(spi_bus(), iodata()) :: binary()
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
  @spec close(spi_bus()) :: :ok
  def close(spi_bus) do
    Nif.close(spi_bus)
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
    Path.wildcard("/dev/spidev*")
    |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
  end

  @doc """
  Return info about the low level SPI interface

  This may be helpful when debugging SPI issues.
  """
  @spec info() :: map()
  defdelegate info(), to: Nif

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
  @spec max_transfer_size() :: non_neg_integer()
  defdelegate max_transfer_size(), to: Nif
end
