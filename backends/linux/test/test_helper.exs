# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

if not File.exists?("/dev/spidev0.0") do
  IO.puts(
    "WARNING: Skipping tests that require an accessible SPI device with MISO and MOSI connected. See README_TESTING.md."
  )

  ExUnit.configure(exclude: :spidev)
end

ExUnit.start()
