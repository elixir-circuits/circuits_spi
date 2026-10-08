# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defprotocol Circuits.SPI.Bus do
  @moduledoc """
  A bus is the connection to a real or virtual SPI controller
  """

  alias Circuits.SPI

  @doc """
  Return the configuration for this SPI bus

  The configuration could differ from what was given to `Circuits.SPI.open/2` if
  the device had to adjust it to work.
  """
  @spec config(t()) :: {:ok, SPI.spi_option_map()} | {:error, term()}
  def config(bus)

  @doc """
  Transfer data

  Since each SPI transfer sends and receives simultaneously, success returns
  `{:ok, received}`, where `received` is a binary with the same byte count as
  `data`. For nested iodata, this is `IO.iodata_length(data)`.

  Transfer limits and segmentation behavior are backend-specific. See
  `Circuits.SPI.transfer/2` for the Linux backend's behavior.
  """
  @spec transfer(t(), iodata()) :: {:ok, binary()} | {:error, term()}
  def transfer(bus, data)

  @doc """
  Write data

  This works identically to `transfer/2` except that it ignores all received data.
  """
  @spec write(t(), iodata()) :: :ok | {:error, term()}
  def write(bus, data)

  @doc """
  Read `len` bytes

  This works identically to `transfer/2` except that the bits written are whatever
  the controller chooses. The expectation is that the device on the other side
  is ignoring them anyway.
  """
  @spec read(t(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def read(bus, len)

  @doc """
  Free up resources associated with the bus

  Well-behaved backends free up their resources with the help of the Erlang
  garbage collector. However, it is good practice for users to call
  `Circuits.SPI.close/1` (and hence this function) so that limited resources are
  freed before they're needed again.
  """
  @spec close(t()) :: :ok
  def close(bus)

  @doc """
  Return the maximum size of a single low-level transfer in bytes

  This is not necessarily the maximum message size accepted by the backend.
  For example, the Linux backend uses the `spidev` driver's `bufsiz` parameter
  as this limit and automatically splits larger messages into multiple
  transfers. Chip select is deasserted between them.

  Use this limit to determine whether a command fits in one transfer rather
  than assuming that manual splitting is required. See
  `Circuits.SPI.transfer/2` for details.
  """
  @spec max_transfer_size(t()) :: non_neg_integer()
  def max_transfer_size(bus)
end
