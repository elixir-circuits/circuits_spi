# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.LinuxBackendNIFTest do
  use ExUnit.Case

  alias Circuits.SPI.LinuxBackendNIF

  describe "info/0" do
    test "info identifies as expected" do
      info = LinuxBackendNIF.info()

      assert is_map(info)
      assert info.description == "Linux spidev driver"
    end
  end

  describe "open/1" do
    test "bad spi device fails" do
      assert {:error, :access_denied} =
               LinuxBackendNIF.open("does_not_exist", 0, 8, 1_000_000, 10, false)
    end
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.SPI.LinuxBackendNIF} ==
               :code.ensure_loaded(Circuits.SPI.LinuxBackendNIF)

      # Try running something to verify that it works.
      _ = LinuxBackendNIF.info()

      assert true == :code.delete(Circuits.SPI.LinuxBackendNIF)

      # The purge will call the unload which can be verified by turning DEBUG on
      # in the C code.
      assert false == :code.purge(Circuits.SPI.LinuxBackendNIF)
    end
  end

  test "setting backend to unknown value doesn't load the NIF" do
    original_backends = Application.get_env(:circuits_spi, :backends)

    # Unload the current code if loaded
    _ = :code.delete(Circuits.SPI.LinuxBackendNIF)
    _ = :code.purge(Circuits.SPI.LinuxBackendNIF)

    # Attempt loading. NIF shouldn't be loaded this time.
    Application.put_env(:circuits_spi, :backends, [Some.Other.Backend])

    assert {:module, Circuits.SPI.LinuxBackendNIF} ==
             :code.ensure_loaded(Circuits.SPI.LinuxBackendNIF)

    assert_raise UndefinedFunctionError, fn -> Circuits.SPI.backend_info() end

    # Cleanup
    assert true == :code.delete(Circuits.SPI.LinuxBackendNIF)
    assert false == :code.purge(Circuits.SPI.LinuxBackendNIF)
    Application.put_env(:circuits_spi, :backends, original_backends)
  end

  describe "load tests" do
    test "unloading NIF" do
      # The theory here is that there shouldn't be a crash if this is reloaded a
      # few times.
      for _times <- 1..10 do
        assert {:module, Circuits.SPI.LinuxBackendNIF} ==
                 :code.ensure_loaded(Circuits.SPI.LinuxBackendNIF)

        # Try running something to verify that it works.
        _ = LinuxBackendNIF.info()

        assert true == :code.delete(Circuits.SPI.LinuxBackendNIF)

        # The purge will call the unload which can be verified by turning DEBUG on
        # in the C code.
        assert false == :code.purge(Circuits.SPI.LinuxBackendNIF)
      end

      # Load it again for any other subsequent tests
      assert {:module, Circuits.SPI.LinuxBackendNIF} ==
               :code.ensure_loaded(Circuits.SPI.LinuxBackendNIF)
    end
  end
end
