defmodule ElixirCircuits.SPI do
  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via a SPI bus.
  """

  alias ElixirCircuits.SPI.Nif, as: Nif

  # Public API

  @doc """
  SPI bus options include:
  * `mode`: This specifies the clock polarity and phase to use. (0)
  * `bits_per_word`: bits per word on the bus (8)
  * `speed_hz`: bus speed (1000000)
  * `delay_us`: delay between transaction (10)
  """

  # NOTE: for :bits_per_word, 0 is interpreted as 8-bits

  @type spi_option ::
    {:mode, 0..3}
    | {:bits_per_word, 0..16}
    | {:speed_hz, pos_integer}
    | {:delay_us, non_neg_integer}

  @doc """
  Open SPI channel
  On success, returns an integer file descriptor.
  Use file descriptor (fd) in subsequent calls to transfer spi bus data
  Parameters:
  * `device` is the Linux device name for the bus (e.g., "spidev0.0")
  * `spi_opts` is a keyword list to configure the bus
  """
  @spec open(binary, [spi_option]) :: {:ok, integer}
  def open(device, spi_opts \\ []) do
    mode = Keyword.get(spi_opts, :mode, 0)
    bits_per_word = Keyword.get(spi_opts, :bits_per_word, 8)
    speed_hz = Keyword.get(spi_opts, :speed_hz, 1_000_000)
    delay_us = Keyword.get(spi_opts, :delay_us, 10)
    Nif.open(to_charlist(device), mode, bits_per_word, speed_hz, delay_us)
  end

  @doc """
  Perform a SPI transfer. The `data` should be a binary containing the bytes to
  send. Since SPI transfers simultaneously send and receive, the return value
  will be a binary of the same length or an error.
  """
  @spec transfer(integer, binary) :: {:ok, binary} | {:error, term}
  def transfer(fd, data) do
    Nif.transfer(fd, data)
  end

  @doc """
  Release any resources associated with the given file descriptior
  """
  @spec close(integer) :: :ok
  def close(fd) do
    Nif.close(fd)
  end

  @doc """
  Return a list of available SPI bus device names.  If nothing is returned,
  it's possible that the kernel driver for that SPI bus is not enabled or the
  kernel's device tree is not configured. On Raspbian, run `raspi-config` and
  look in the advanced options.
  ```
  iex> ElixirCircuits.SPI.device_names
  ["spidev0.0", "spidev0.1"]
  ```
  """
  @spec device_names() :: [binary]
  def device_names() do
    Path.wildcard("/dev/spidev*")
    |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
  end

end
