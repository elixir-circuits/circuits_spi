# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.SPIDev do
  @moduledoc """
  Circuits.SPI backend for the Linux spidev interface

  This backend works on Nerves, embedded Linux, and desktop Linux.
  """
  @behaviour Circuits.SPI.Backend

  alias Circuits.SPI.Backend
  alias Circuits.SPI.Bus
  alias Circuits.SPI.Nif

  defstruct [:ref]

  @doc """
  Return the SPI bus names on this system

  No supported options
  """
  case System.get_env("CIRCUITS_SPI_SPIDEV") do
    "test" ->
      @impl Backend
      def bus_names(_options), do: ["spidev0.0"]

    "normal" ->
      @impl Backend
      def bus_names(_options) do
        Path.wildcard("/dev/spidev*")
        |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
      end

    _ ->
      @impl Backend
      def bus_names(_options) do
        []
      end
  end

  @doc """
  Open an SPI bus
  """
  @impl Backend
  def open(bus_name, options) do
    mode = Keyword.get(options, :mode, 0)
    bits_per_word = Keyword.get(options, :bits_per_word, 8)
    speed_hz = Keyword.get(options, :speed_hz, 1_000_000)
    delay_us = Keyword.get(options, :delay_us, 10)
    lsb_first = Keyword.get(options, :lsb_first, false)

    with {:ok, ref} <-
           Nif.open(to_string(bus_name), mode, bits_per_word, speed_hz, delay_us, lsb_first) do
      {:ok, %__MODULE__{ref: ref}}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    Nif.info()
    |> Map.put(:backend, __MODULE__)
  end

  defimpl Bus do
    @impl Bus
    def config(%Circuits.SPI.SPIDev{ref: ref}) do
      Nif.config(ref)
    end

    @impl Bus
    def transfer(%Circuits.SPI.SPIDev{ref: ref}, data) do
      Nif.transfer(ref, data)
    end

    @impl Bus
    def close(%Circuits.SPI.SPIDev{ref: ref}) do
      Nif.close(ref)
    end

    @impl Bus
    def max_transfer_size(%Circuits.SPI.SPIDev{}) do
      Nif.max_transfer_size()
    end
  end
end
