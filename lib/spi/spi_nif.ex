defmodule ElixirCircuits.SPI.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @doc """
  Elixir interface to SPI Natively Implemented Funtions (NIFs)
  """

  def load_nif() do
    nif_binary = Application.app_dir(:spi, "priv/spi_nif")
    if File.exists?(nif_binary) do
      :erlang.load_nif(to_charlist(nif_binary), 0)
    else
      IO.puts("WARNING: Not loading SPI NIF since not compiled or not supported on this platform")
    end
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
