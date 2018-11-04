defmodule CircuitsSPITest do
  use ExUnit.Case

  test "info returns a map" do
    info = Circuits.SPI.info()

    assert is_map(info)
    assert Map.has_key?(info, :name)
  end
end
