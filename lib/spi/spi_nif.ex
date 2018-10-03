defmodule ElixirCircuits.SPI.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @doc """
  Elixir interface to SPI Natively Implemented Funtions (NIFs)
  """

  def load_nif() do
    nif_exec = '#{:code.priv_dir(:spi)}/spi_nif'
    :erlang.load_nif(nif_exec, 0)
  end

  def open(_device, _mode, _bits_per_word, _speed_hz, _delay_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def transfer(_fd, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_fd) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
