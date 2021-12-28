defmodule Circuits.SPI.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @moduledoc false

  def load_nif() do
    nif_binary = Application.app_dir(:circuits_spi, "priv/spi_nif")
    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def open(_bus_name, _mode, _bits_per_word, _speed_hz, _delay_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def transfer(_ref, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_ref) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def info() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def max_transfer_size() do
    :erlang.nif_error(:nif_not_loaded)
  end
end
