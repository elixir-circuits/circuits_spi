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

  The configuration could be different that what was given to `open/2` if
  the device had to change it for it to work.
  """
  @spec config(t()) :: {:ok, SPI.spi_option_map()} | {:error, term()}
  def config(bus)

  @doc """
  Transfer data

  Since each SPI transfer sends and receives simultaneously, the return value
  will be a binary of the same length as `data`.
  """
  @spec transfer(t(), iodata()) :: {:ok, binary()} | {:error, term()}
  def transfer(bus, data)

  @doc """
  Free up resources associated with the bus

  Well behaved backends free up their resources with the help of the Erlang garbage collector. However, it is good
  practice for users to call `Circuits.SPI.close/1` (and hence this function) so that
  limited resources are freed before they're needed again.
  """
  @spec close(t()) :: :ok
  def close(bus)

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
  @spec max_transfer_size(t()) :: non_neg_integer()
  def max_transfer_size(bus)
end
