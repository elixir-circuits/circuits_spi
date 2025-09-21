# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPINifTest do
  use ExUnit.Case

  alias Circuits.SPI.Nif

  describe "info/0" do
    test "info identifies as a spi_dev_test and not a real spi driver" do
      info = Nif.info()

      assert is_map(info)
      assert info.name == :stub
    end
  end

  describe "open/1" do
    test "my_spidev work" do
      {:ok, spi} = Nif.open("my_spidev", 0, 8, 1_000_000, 10, false)
      Nif.close(spi)
    end
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.SPI.Nif} == :code.ensure_loaded(Circuits.SPI.Nif)

      # Try running something to verify that it works.
      {:ok, spi} = Nif.open("my_spidev", 0, 8, 1_000_000, 10, false)
      assert is_reference(spi)
      Nif.close(spi)

      assert true == :code.delete(Circuits.SPI.Nif)

      # The purge will call the unload which can be verified by turning DEBUG on
      # in the C code.
      assert false == :code.purge(Circuits.SPI.Nif)
    end
  end

  test "setting backend to unknown value doesn't load the NIF" do
    original_backend = Application.get_env(:circuits_spi, :default_backend)

    # Unload the current code if loaded
    _ = :code.delete(Circuits.SPI.Nif)
    _ = :code.purge(Circuits.SPI.Nif)

    # Attempt loading. NIF shouldn't be loaded this time.
    Application.put_env(:circuits_spi, :default_backend, Some.Other.Backend)
    assert {:module, Circuits.SPI.Nif} == :code.ensure_loaded(Circuits.SPI.Nif)
    assert_raise UndefinedFunctionError, fn -> Circuits.SPI.info() end

    # Cleanup
    assert true == :code.delete(Circuits.SPI.Nif)
    assert false == :code.purge(Circuits.SPI.Nif)
    Application.put_env(:circuits_spi, :default_backend, original_backend)
  end

  describe "load tests" do
    test "unloading NIF" do
      # The theory here is that there shouldn't be a crash if this is reloaded a
      # few times.
      for _times <- 1..10 do
        assert {:module, Circuits.SPI.Nif} == :code.ensure_loaded(Circuits.SPI.Nif)

        # Try running something to verify that it works.
        {:ok, spi} = Nif.open("my_spidev", 0, 8, 1_000_000, 10, false)
        assert is_reference(spi)
        Nif.close(spi)

        assert true == :code.delete(Circuits.SPI.Nif)

        # The purge will call the unload which can be verified by turning DEBUG on
        # in the C code.
        assert false == :code.purge(Circuits.SPI.Nif)
      end

      # Load it again for any other subsequent tests
      assert {:module, Circuits.SPI.Nif} == :code.ensure_loaded(Circuits.SPI.Nif)
    end
  end
end
