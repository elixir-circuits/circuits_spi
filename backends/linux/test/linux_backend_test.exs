# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Cocoa Xu
#
# SPDX-License-Identifier: Apache-2.0

defmodule CircuitsSPI.LinuxBackendTest do
  use ExUnit.Case
  @moduletag :linux

  # All possible byte values needed for lsb <-> msb test
  @test_data :binary.list_to_bin(for i <- 0..255, do: i)

  test "info/0" do
    info = Circuits.SPI.info()

    assert is_map(info)
    assert info.name == Circuits.SPI.LinuxBackend
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
    assert config.lsb_first == false
    assert config.sw_lsb_first == false
  end

  test "transfers loop back using stub" do
    {:ok, spi} = Circuits.SPI.open("my_spidev")

    {:ok, result} = Circuits.SPI.transfer(spi, @test_data)

    assert result == @test_data
  end

  test "transfers loop back using stub and lsb_first" do
    {:ok, spi} = Circuits.SPI.open("my_spidev", lsb_first: true)
    {:ok, config} = Circuits.SPI.config(spi)
    assert config.lsb_first == true
    assert config.sw_lsb_first == true

    {:ok, result} = Circuits.SPI.transfer(spi, @test_data)

    assert result == @test_data
  end

  test "iodata transfers work" do
    {:ok, spi} = Circuits.SPI.open("my_spidev", lsb_first: true)

    message = ["Hello", [1, 2, 3, @test_data]]
    expected = IO.iodata_to_binary(message)

    {:ok, result} = Circuits.SPI.transfer(spi, message)

    assert result == expected
  end
end
