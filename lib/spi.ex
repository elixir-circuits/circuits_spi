defmodule Circuits.SPI do
  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via a SPI bus.
  """

  alias Circuits.SPI.Nif

  @typedoc """
  SPI bus options. See `open/2`.
  """
  @type spi_option ::
          {:mode, 0..3}
          | {:bits_per_word, 0..16}
          | {:speed_hz, pos_integer()}
          | {:delay_us, non_neg_integer()}

  @typedoc """
  SPI bus

  Call `open/2` to obtain an SPI bus reference.
  """
  @type spi_bus() :: reference()

  @doc """
  Open SPI channel
  On success, returns a reference.
  Use reference in subsequent calls to transfer SPI bus data

  Parameters:
  * `bus_name` is the name of the bus (e.g., "spidev0.0")
  * `opts` is a keyword list to configure the bus

  SPI bus options include:
  * `mode`: This specifies the clock polarity and phase to use. (0)
  * `bits_per_word`: bits per word on the bus (8)
  * `speed_hz`: bus speed (1000000)
  * `delay_us`: delay between transaction (10)
  """
  @spec open(binary() | charlist(), [spi_option()]) :: {:ok, spi_bus()}
  def open(bus_name, opts \\ []) do
    mode = Keyword.get(opts, :mode, 0)
    bits_per_word = Keyword.get(opts, :bits_per_word, 8)
    speed_hz = Keyword.get(opts, :speed_hz, 1_000_000)
    delay_us = Keyword.get(opts, :delay_us, 10)
    Nif.open(to_charlist(bus_name), mode, bits_per_word, speed_hz, delay_us)
  end

  @doc """
  Perform a SPI transfer. The `data` should be a binary containing the bytes to
  send. Since SPI transfers simultaneously send and receive, the return value
  will be a binary of the same length or an error.
  """
  @spec transfer(spi_bus(), binary()) :: {:ok, binary()} | {:error, term()}
  def transfer(spi_bus, data) do
    Nif.transfer(spi_bus, data)
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

  defmodule :circuits_spi do
    @moduledoc """
    Provide an Erlang friendly interface to Circuits
    Example Erlang code:  circuits_spi:open("spidev0.1")
    """
    defdelegate open(bus_name), to: Circuits.SPI
    defdelegate open(bus_name, spi_opts), to: Circuits.SPI
    defdelegate transfer(ref, data), to: Circuits.SPI
    defdelegate close(ref), to: Circuits.SPI
  end
end
