defmodule CircuitsSPITest do
  use ExUnit.Case

  test "info returns a map" do
    info = Circuits.SPI.info()

    assert is_map(info)
    assert Map.has_key?(info, :name)
  end

  test "max buffer size returns an non-negative integer" do
    max_transfer_size = Circuits.SPI.max_transfer_size()
    assert is_integer(max_transfer_size)
    assert max_transfer_size >= 0
  end

  test "config comes back with documented defaults" do
    {:ok, spi} = Circuits.SPI.open("my_spidev")

    {:ok, config} = Circuits.SPI.config(spi)
    assert config.mode == 0
    assert config.bits_per_word == 8
    assert config.delay_us == 10
    assert config.speed_hz == 1_000_000
  end
end
