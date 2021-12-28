defmodule CircuitsSPITest do
  use ExUnit.Case

  test "info returns a map" do
    info = Circuits.SPI.info()

    assert is_map(info)
    assert Map.has_key?(info, :name)
  end

  test "max buffer size returns an non-negative integer" do
    max_buf_size = Circuits.SPI.max_buf_size()
    assert is_integer(max_buf_size)
    assert max_buf_size >= 0
  end
end
