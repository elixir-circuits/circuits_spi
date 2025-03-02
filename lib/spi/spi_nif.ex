# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Mark Sebald
# SPDX-FileCopyrightText: 2021 Cocoa Xu
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.Nif do
  @moduledoc false

  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  def load_nif() do
    :erlang.load_nif(:code.priv_dir(:circuits_spi) ++ ~c"/spi_nif", 0)
  end

  def open(_bus_name, _mode, _bits_per_word, _speed_hz, _delay_us, _lsb_first),
    do: :erlang.nif_error(:nif_not_loaded)

  def config(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def transfer(_ref, _data), do: :erlang.nif_error(:nif_not_loaded)
  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def max_transfer_size(), do: :erlang.nif_error(:nif_not_loaded)
  def info(), do: :erlang.nif_error(:nif_not_loaded)
end
