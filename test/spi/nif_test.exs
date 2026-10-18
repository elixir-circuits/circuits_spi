# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.SPI.NifTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Circuits.SPI.Nif

  test "hot reload preserves open bus handle and configuration" do
    assert {:module, Nif} == :code.ensure_loaded(Nif)
    {:ok, spi} = Nif.open("my_spidev", 3, 8, 500_000, 10, true)

    try do
      assert {:ok, <<1, 2, 3>>} == Nif.transfer(spi, <<1, 2, 3>>)
      assert {:ok, config} = Nif.config(spi)
      assert config.mode == 3
      assert config.speed_hz == 500_000
      assert config.delay_us == 10
      assert config.lsb_first
      assert config.sw_lsb_first

      {Nif, binary, filename} = :code.get_object_code(Nif)

      for _times <- 1..3 do
        # Simulate a hot code reload by manually loading the binary again
        assert {:module, Nif} == :code.load_binary(Nif, filename, binary)
        assert :code.soft_purge(Nif)

        assert {:ok, config} == Nif.config(spi)
        assert {:ok, <<1, 2, 3>>} == Nif.transfer(spi, <<1, 2, 3>>)
        assert :ok == Nif.write(spi, <<1>>)
        assert {:ok, <<0, 0, 0>>} == Nif.read(spi, 3)
      end
    after
      assert :ok == Nif.close(spi)
    end
  end

  @tag :tmp_dir
  test "hot reload fails on ABI mismatch", %{tmp_dir: tmp_dir} do
    assert {:module, Nif} == :code.ensure_loaded(Nif)

    original_app_dir = Application.app_dir(:circuits_spi)
    original_ebin = String.to_charlist(Path.join(original_app_dir, "ebin"))

    on_exit(fn ->
      assert true == :code.replace_path(:circuits_spi, original_ebin)
    end)

    app_dir = create_incompatible_app(original_app_dir, tmp_dir)
    {:ok, spi} = Nif.open("my_spidev", 0, 8, 1_000_000, 0, false)

    try do
      true = :code.replace_path(:circuits_spi, String.to_charlist(Path.join(app_dir, "ebin")))

      log =
        capture_log(fn ->
          assert {:error, :on_load_failure} = :code.load_file(Nif)
          # OTP emits the on_load failure warning asynchronously so wait a bit
          Process.sleep(50)
        end)

      assert log =~ "[warning] The on_load function for module Elixir.Circuits.SPI.Nif returned"
      assert {:ok, <<1, 2, 3>>} == Nif.transfer(spi, <<1, 2, 3>>)
    after
      assert :ok == Nif.close(spi)
    end
  end

  defp create_incompatible_app(src_app_dir, tmp_dir) do
    new_app_dir = Path.join(tmp_dir, "circuits_spi")
    File.cp_r!(src_app_dir, new_app_dir)

    # Binary patch the shared library to give it a new ABI
    nif_path = Path.join(new_app_dir, "priv/spi_nif.so")
    original_nif = File.read!(nif_path)
    new_nif = :binary.replace(original_nif, "spi_nif_res_v1", "spi_nif_res_v2")
    assert original_nif != new_nif
    File.write!(nif_path, new_nif)
    code_sign(nif_path, :os.type())

    new_app_dir
  end

  defp code_sign(path, {:unix, :darwin}) do
    {_, 0} = System.cmd("codesign", ["--force", "--sign", "-", path], stderr_to_stdout: true)
    :ok
  end

  defp code_sign(_path, _other), do: :ok
end
