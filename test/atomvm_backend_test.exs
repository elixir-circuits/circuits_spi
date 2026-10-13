# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.AtomVMBackendTest do
  use ExUnit.Case, async: true

  alias Circuits.SPI.AtomVMBackend
  alias Circuits.SPI.Bus

  defmodule SPI do
    def open(config), do: {:spi, self(), config}

    def write_read({:spi, owner, _config}, device, transaction) do
      send(owner, {:write_read, device, transaction})

      result =
        case transaction do
          %{write_data: data} -> data
          %{read_bits: read_bits} -> <<0::size(read_bits)>>
        end

      {:ok, result}
    end

    def write({:spi, owner, _config}, device, transaction) do
      send(owner, {:write, device, transaction})
      :ok
    end

    def close({:spi, owner, _config}) do
      send(owner, :close)
      :ok
    end
  end

  @backend_options [
    spi_module: SPI,
    buses: %{
      "display" => [
        bus_config: [sclk: 18, mosi: 23, miso: 19, peripheral: "spi2"],
        device_config: [cs: 5, mode: 1, clock_speed_hz: 500_000]
      ]
    }
  ]

  test "lists configured buses and reports backend information" do
    assert AtomVMBackend.bus_names(@backend_options) == ["display"]

    assert AtomVMBackend.info(@backend_options) == %{
             description: "AtomVM SPI HAL",
             bus_names: ["display"]
           }
  end

  test "opens a configured bus and applies Circuits.SPI option overrides" do
    assert {:ok, bus} =
             AtomVMBackend.open(
               "display",
               Keyword.merge(@backend_options, mode: 3, speed_hz: 2_000_000)
             )

    assert {:spi, _owner,
            [
              bus_config: [sclk: 18, mosi: 23, miso: 19, peripheral: "spi2"],
              device_config: [
                circuits_spi: [clock_speed_hz: 2_000_000, mode: 3, cs: 5]
              ]
            ]} = bus.ref

    assert {:ok,
            %{
              mode: 3,
              bits_per_word: 8,
              speed_hz: 2_000_000,
              delay_us: 0,
              lsb_first: false,
              sw_lsb_first: false
            }} = Bus.config(bus)
  end

  test "implements transfer, write, read, and close" do
    assert {:ok, bus} = AtomVMBackend.open("display", @backend_options)

    assert {:ok, <<1, 2, 3>>} = Bus.transfer(bus, [<<1>>, [2, 3]])
    assert_receive {:write_read, :circuits_spi, %{write_data: <<1, 2, 3>>}}

    assert :ok = Bus.write(bus, [4, 5])
    assert_receive {:write, :circuits_spi, %{write_data: <<4, 5>>}}

    assert {:ok, <<0, 0>>} = Bus.read(bus, 2)
    assert_receive {:write_read, :circuits_spi, %{read_bits: 16}}

    assert :ok = Bus.close(bus)
    assert_receive :close

    assert Bus.max_transfer_size(bus) == 4092
  end

  test "segments transfers at AtomVM's default maximum transaction size" do
    assert {:ok, bus} = AtomVMBackend.open("display", @backend_options)
    data = :binary.copy(<<1>>, 4093)

    assert {:ok, ^data} = Bus.transfer(bus, data)
    assert_receive {:write_read, :circuits_spi, %{write_data: chunk1}}
    assert_receive {:write_read, :circuits_spi, %{write_data: chunk2}}
    assert byte_size(chunk1) == 4092
    assert byte_size(chunk2) == 1

    assert {:ok, result} = Bus.read(bus, 4093)
    assert byte_size(result) == 4093
    assert_receive {:write_read, :circuits_spi, %{read_bits: 32_736}}
    assert_receive {:write_read, :circuits_spi, %{read_bits: 8}}
  end

  test "returns errors for unknown buses and unsupported options" do
    assert {:error, :not_found} = AtomVMBackend.open("missing", @backend_options)

    assert {:error, {:unsupported_bits_per_word, 16}} =
             AtomVMBackend.open("display", Keyword.put(@backend_options, :bits_per_word, 16))

    assert {:error, {:unsupported_option, :lsb_first}} =
             AtomVMBackend.open("display", Keyword.put(@backend_options, :lsb_first, true))

    assert {:error, {:missing_option, :bus_config}} =
             AtomVMBackend.open(
               "invalid",
               Keyword.put(@backend_options, :buses, %{"invalid" => []})
             )
  end
end
