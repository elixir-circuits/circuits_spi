# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.Backend do
  @moduledoc """
  Backends provide the connection to the real or virtual SPI controller

  Select a backend with the `:circuits_spi, :default_backend` application
  configuration. The value may be a backend module or a
  `{backend_module, default_options}` tuple. See `Circuits.SPI` for details.

  A backend's `c:open/2` callback returns a bus value that implements the
  `Circuits.SPI.Bus` protocol. The protocol provides configuration, transfer,
  read, write, close, and maximum transfer size operations for that value.
  """
  alias Circuits.SPI
  alias Circuits.SPI.Bus

  @doc """
  Return SPI bus names on this system

  No options are supported.
  """
  @callback bus_names(options :: keyword()) :: [String.t()]

  @doc """
  Open an SPI bus device

  On success, `open/2` returns `{:ok, bus}`, where `bus` implements
  `Circuits.SPI.Bus` and may be passed to `Circuits.SPI.transfer/2` and the
  other bus operations.

  Backends should release resources when the bus is garbage collected and
  support explicit cleanup through `Circuits.SPI.Bus.close/1`.

  SPI is not a standardized interface, so appropriate options will
  differ from device to device. The defaults used here work on
  many devices.

  Parameters:
  * `bus_name` is the name of the bus (e.g., "spidev0.0"). See `c:bus_names/1`
  * The second argument is a keyword list to configure the bus
  """
  @callback open(bus_name :: String.t(), [SPI.spi_option()]) ::
              {:ok, Bus.t()} | {:error, term()}

  @doc """
  Return information about this backend
  """
  @callback info() :: map()
end
