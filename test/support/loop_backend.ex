# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.LoopBackend do
  @moduledoc """
  Circuits.SPI backend when nothing else is available
  """
  @behaviour Circuits.SPI.Backend

  alias Circuits.SPI.Backend
  alias Circuits.SPI.Bus

  defstruct mode: 0,
            bits_per_word: 8,
            speed_hz: 1_000_000,
            delay_us: 0,
            lsb_first: false,
            sw_lsb_first: false

  @doc """
  Return the SPI bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options), do: ["loop"]

  @doc """
  Open an I2C bus

  No supported options.
  """
  @impl Backend
  def open("loop", options), do: {:ok, struct(__MODULE__, options)}
  def open(_bus, _options), do: {:error, :not_found}

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info(_options) do
    %{description: "Loopback SPI backend"}
  end

  defimpl Bus do
    @impl Bus
    def config(%Circuits.SPI.LoopBackend{} = spi) do
      {:ok, Map.from_struct(spi)}
    end

    @impl Bus
    def transfer(%Circuits.SPI.LoopBackend{}, data) do
      {:ok, IO.iodata_to_binary(data)}
    end

    @impl Bus
    def write(%Circuits.SPI.LoopBackend{}, _data) do
      :ok
    end

    @impl Bus
    def read(%Circuits.SPI.LoopBackend{}, len) do
      {:ok, :binary.copy(<<0>>, len)}
    end

    @impl Bus
    def close(%Circuits.SPI.LoopBackend{}) do
      :ok
    end

    @impl Bus
    def max_transfer_size(%Circuits.SPI.LoopBackend{}) do
      4096
    end
  end
end
