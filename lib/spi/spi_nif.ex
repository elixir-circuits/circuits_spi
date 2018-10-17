defmodule ElixirCircuits.SPI.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  require Logger

  @doc """
  Elixir interface to SPI Natively Implemented Funtions (NIFs)
  """

  def load_nif() do
    nif_binary = Application.app_dir(:spi, "priv/spi_nif")

    case :erlang.load_nif(to_charlist(nif_binary), 0) do
      {:error, reason} ->
        Logger.error(
          "ElixirCircuits.I2CError: load_nif(#{nif_binary}) failed with #{inspect(reason)}"
        )

      _ ->
        :ok
    end
  end

  def open(_device, _mode, _bits_per_word, _speed_hz, _delay_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def transfer(_ref, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_ref) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
