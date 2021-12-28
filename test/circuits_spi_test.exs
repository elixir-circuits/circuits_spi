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
end
