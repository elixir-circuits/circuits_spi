# SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.Nif do
  @moduledoc false

  defp load_nif() do
    nif_binary = Application.app_dir(:circuits_spi, "priv/spi_nif")
    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def open(bus_name, mode, bits_per_word, speed_hz, delay_us, lsb_first) do
    with :ok <- load_nif() do
      apply(__MODULE__, :open, [bus_name, mode, bits_per_word, speed_hz, delay_us, lsb_first])
    end
  end

  def config(_ref) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def transfer(_ref, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_ref) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def info() do
    :ok = load_nif()
    apply(__MODULE__, :info, [])
  end

  def max_transfer_size() do
    :erlang.nif_error(:nif_not_loaded)
  end
end
