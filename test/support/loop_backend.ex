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

  defstruct []

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
  def open("loop", _options), do: {:ok, %__MODULE__{}}
  def open(_bus, _options), do: {:error, :not_found}

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{name: __MODULE__}
  end

  defimpl Bus do
    @impl Bus
    def config(%Circuits.SPI.LoopBackend{}) do
      {:ok,
       %{
         mode: 0,
         bits_per_word: 8,
         speed_hz: 1_000_000,
         delay_us: 10,
         lsb_first: false,
         sw_lsb_first: false
       }}
    end

    @impl Bus
    def transfer(%Circuits.SPI.LoopBackend{}, data) do
      {:ok, IO.iodata_to_binary(data)}
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
