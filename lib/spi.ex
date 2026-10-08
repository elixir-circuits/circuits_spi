# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Mark Sebald
# SPDX-FileCopyrightText: 2021 Cocoa Xu
# SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI do
  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via an SPI bus.

  ## Backends

  The `:default_backend` application configuration selects the backend used by
  `open/2`, `bus_names/0`, and `info/0`. Set it in `config/config.exs` before
  compiling dependencies. For example, to use simulated SPI devices:

  ```elixir
  import Config

  config :circuits_spi, default_backend: CircuitsSim.SPI.Backend
  ```

  This requires the `:circuits_sim` dependency and configured simulated devices.
  See the [README's CircuitsSim example](readme.html#how-do-i-use-circuitssim)
  for a complete setup.

  The value may be a backend module or a `{backend_module, default_options}`
  tuple. Options passed to `open/2` override the backend's default options.
  Alternative backends implement `Circuits.SPI.Backend` and return bus values
  that implement the `Circuits.SPI.Bus` protocol.
  """

  alias Circuits.SPI.Bus

  @typedoc """
  Backends specify an implementation of the `Circuits.SPI.Backend` behaviour

  The second element of the backend 2-tuple is a list of options. These are
  passed to the backend's callback implementations.
  """
  @type backend() :: {module(), keyword()}

  @typedoc """
  SPI bus options

  See `open/2` for option descriptions and defaults.
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
  Open an SPI bus device

  On success, `open/2` returns `{:ok, bus}`, where `bus` is a backend-specific
  value that implements `Circuits.SPI.Bus`. Pass it to `transfer/2` and the
  other bus operations.

  The Linux backend releases the device when the bus's underlying resource is
  garbage collected. Call `close/1` to release it promptly rather than waiting
  for garbage collection.

  ## Parameters

  * `bus_name` is the name of the bus (e.g., "spidev0.0"). See `bus_names/0`
  * `options` is a keyword list to configure the bus

  ## Options

  The Linux backend supports the following options and defaults. Supported
  settings depend on the controller and peripheral. Other backends may have
  different defaults or support additional options.

  * `:mode` - Set the clock polarity and phase. Defaults to `0`:
    * Mode 0 (CPOL=0, CPHA=0) - Clock idle low; sample on the leading edge
    * Mode 1 (CPOL=0, CPHA=1) - Clock idle low; sample on the trailing edge
    * Mode 2 (CPOL=1, CPHA=0) - Clock idle high; sample on the leading edge
    * Mode 3 (CPOL=1, CPHA=1) - Clock idle high; sample on the trailing edge
  * `:bits_per_word` - Set the number of bits per word, from `8` to `16`.
    Defaults to `8`.
  * `:speed_hz` - Set the clock frequency in Hz. Must be a positive integer.
    Defaults to `1_000_000` (1 MHz). Supported speeds are device-specific.
  * `:delay_us` - Set the delay after a transfer, before chip select is
    deasserted, in microseconds. Must be a non-negative integer. Defaults to `0`.
  * `:lsb_first` - Set to `true` to send the least significant bit first rather
    than the most significant bit. Defaults to `false`. If the hardware does
    not support LSB-first mode, Circuits.SPI reverses the bits in software.
    The hardware may print `unsupported mode bits 8` in this case; this message
    can be ignored.

  Options passed here override the configured backend's default options.
  Use `config/1` to check the configuration actually selected by the backend.

  ## Examples

  ```elixir
  {:ok, spi} = Circuits.SPI.open("spidev0.0", mode: 0, speed_hz: 500_000)
  ```
  """
  @spec open(binary(), [spi_option()]) :: {:ok, Bus.t()} | {:error, term()}
  def open(bus_name, options \\ []) when is_binary(bus_name) do
    {module, default_options} = default_backend()
    module.open(bus_name, Keyword.merge(default_options, options))
  end

  @doc """
  Return the configuration for this SPI bus

  The configuration could differ from what was given to `open/2` if
  the device had to adjust it to work.
  """
  @spec config(Bus.t()) :: {:ok, spi_option_map()} | {:error, term()}
  def config(spi_bus) do
    Bus.config(spi_bus)
  end

  @doc """
  Transfer data

  Since each SPI transfer sends and receives simultaneously, success returns
  `{:ok, received}`, where `received` is a binary with the same byte count as
  `data`. For nested iodata, this is `IO.iodata_length(data)`.

  The Linux backend automatically splits large data buffers into chunks no
  larger than `max_transfer_size/1`. Manual splitting is not required. Each
  chunk is a separate SPI transfer: chip select is deasserted between chunks,
  and there may be a short pause. If your device requires chip select to remain
  asserted throughout a command, keep the command within this limit. Other
  backends may have different transfer limits and segmentation behavior.

  If you have an operation that writes a number of bytes and then reads data back,
  a common pattern is to use `t:iodata/0`. This example writes 0x1 and 0xff and
  then reads 100 bytes all in one transfer.

  ```
  iex> {:ok, <<_, _, result::binary>>} = Circuits.SPI.transfer(spi, [<<0x1, 0xff>>, :binary.copy(<<0>>, 100)])
  iex> byte_size(result)
  100
  ```
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
    transfer(spi_bus, data) |> result1!()
  end

  @doc """
  Write data

  This works identically to `transfer/2` except that it ignores all received data.
  """
  @spec write(Bus.t(), iodata()) :: :ok | {:error, term()}
  def write(spi_bus, data) do
    Bus.write(spi_bus, data)
  end

  @doc """
  Write data and raise on error
  """
  @spec write!(Bus.t(), iodata()) :: :ok
  def write!(spi_bus, data) do
    write(spi_bus, data) |> result2!()
  end

  @doc """
  Read `len` bytes

  This works identically to `transfer/2` except that the bits written are whatever
  the controller chooses. The expectation is that the device on the other side
  is ignoring them anyway.
  """
  @spec read(Bus.t(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def read(spi_bus, len) do
    Bus.read(spi_bus, len)
  end

  @doc """
  Read data and raise on error
  """
  @spec read!(Bus.t(), pos_integer()) :: binary()
  def read!(spi_bus, len) do
    read(spi_bus, len) |> result1!()
  end

  @doc """
  Release any resources associated with the given SPI bus
  """
  @spec close(Bus.t()) :: :ok
  def close(spi_bus) do
    Bus.close(spi_bus)
  end

  @doc """
  Return a list of available SPI bus names. If the list is empty,
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
    {m, o} = default_backend()
    m.bus_names(o)
  end

  @doc """
  Return information about the low-level SPI interface

  This may be helpful when debugging SPI issues.
  """
  @spec info(backend() | nil) :: map()
  def info(backend \\ nil)

  def info(nil), do: info(default_backend())
  def info({backend, _options}), do: backend.info()

  # The two functions here are for Dialyzer
  defp result1!({:ok, result}), do: result
  defp result1!({:error, reason}), do: raise("SPI failure: " <> to_string(reason))

  defp result2!(:ok), do: :ok
  defp result2!({:error, reason}), do: raise("SPI failure: " <> to_string(reason))

  defp default_backend() do
    case Application.get_env(:circuits_spi, :default_backend) do
      nil -> {Circuits.SPI.NilBackend, []}
      m when is_atom(m) -> {m, []}
      {m, o} = value when is_atom(m) and is_list(o) -> value
    end
  end

  @doc """
  Return the maximum size of a single low-level transfer in bytes

  Pass a bus returned by `open/2` to query its backend's limit. For example,
  the Linux `spidev` driver limits each transfer based on its `bufsiz` parameter.

  This is not necessarily the maximum message size accepted by the backend.
  The Linux backend automatically splits larger `transfer/2`, `write/2`, and
  `read/2` operations into multiple transfers. Chip select is deasserted between
  them, so use this limit to determine whether a command fits in one transfer.
  See `transfer/2` for details.

  Calling this function without a bus, or with `nil`, returns `0`. It does not
  query the configured backend.
  """
  @spec max_transfer_size(Bus.t() | nil) :: non_neg_integer()
  def max_transfer_size(bus \\ nil) do
    case bus do
      nil -> 0
      bus -> Bus.max_transfer_size(bus)
    end
  end
end
