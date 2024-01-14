# SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.Nif do
  @moduledoc false

  defp load_nif_and_apply(fun, args) do
    nif_binary = Application.app_dir(:circuits_spi, "priv/spi_nif")

    # Optimistically load the NIF. Handle the possible race.
    case :erlang.load_nif(to_charlist(nif_binary), 0) do
      :ok -> apply(__MODULE__, fun, args)
      {:error, {:reload, _}} -> apply(__MODULE__, fun, args)
      error -> error
    end
  end

  def open(bus_name, mode, bits_per_word, speed_hz, delay_us, lsb_first) do
    load_nif_and_apply(:open, [bus_name, mode, bits_per_word, speed_hz, delay_us, lsb_first])
  end

  def config(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def transfer(_ref, _data), do: :erlang.nif_error(:nif_not_loaded)
  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def max_transfer_size(), do: :erlang.nif_error(:nif_not_loaded)

  def info() do
    load_nif_and_apply(:info, [])
  end
end
