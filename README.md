<!--
  SPDX-License-Identifier: CC-BY-4.0
  SPDX-FileCopyrightText: 2018 Frank Hunleth
-->

# Circuits.SPI

[![Hex version](https://img.shields.io/hexpm/v/circuits_spi.svg "Hex version")](https://hex.pm/packages/circuits_spi)
[![API docs](https://img.shields.io/hexpm/v/circuits_spi.svg?label=hexdocs "API docs")](https://hexdocs.pm/circuits_spi/Circuits.SPI.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/elixir-circuits/circuits_spi/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/elixir-circuits/circuits_spi/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/elixir-circuits/circuits_spi)](https://api.reuse.software/info/github.com/elixir-circuits/circuits_spi)

`Circuits.SPI` lets you communicate with hardware devices using the SPI protocol.

*This is Circuits.SPI v2. Circuits.SPI v1.x is still maintained in the [maint-v1.x branch](https://github.com/elixir-circuits/circuits_spi/tree/maint-v1.x).*

`Circuits.SPI` v2.0  is an almost backwards compatible update to `Circuits.SPI`
v1.x. Here's what's new:

* Linux or Nerves are no longer required. In fact, the NIF supporting them won't
  be compiled if you don't want it.
* Develop using simulated SPI devices with
  [CircuitsSim](https://github.com/elixir-circuits/circuits_sim)
* Use USB->SPI adapters for development on your laptop (Coming soon)

If you've used `Circuits.SPI` v1.x, nearly all of your code will be the same. If
you're a library author, we'd appreciate if you could try this out and update
your `:circuits_spi` dependency to allow v2.0. Details can be found in our
[porting guide](PORTING.md).

## Getting started on Nerves and Linux

If you're using Nerves or compiling on a Raspberry Pi or other device with SPI
support, then add `circuits_spi` like any other Elixir library:

```elixir
def deps do
  [{:circuits_spi, "~> 2.0"}]
end
```

`Circuits.SPI` doesn't load device drivers, so you'll need to load any necessary
ones beforehand. On the Raspberry Pi, the [Adafruit Raspberry Pi SPI
instructions](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-spi)
may be helpful, (This is already enabled for you if you are using Nerves)

A [Serial Peripheral
Interface](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus) (SPI)
bus is a common multi-wire bus used to connect components on a circuit board. A
clock line drives the timing of sending bits between components. Bits on the
Controller Out Peripheral In, `COPI`, line go from the controller (usually the
processor running this library) to the peripheral, and bits on the Controller
In Peripheral Out, `CIPO`, line go the other direction. If you see references
to `MOSI` or `MISO`, those are the former terms for `COPI` and `CIPO`.

Bits transfer on the SPI bus in both directions simultaneously on each
transaction. However, most of the time, programs and devices only care about
bits traveling in one direction at time. For example, when the program makes a
request, the bits sent to the device are important, but the ones received get
ignored. Then when the device sends the response, the program only pays
attention to the received bits. Anything it sends will be ignored by the device
and programs frequently just send zeros. This will become more clear in the
example below.

The final important concept with SPI is the Chip Select, `CS`, line. This is a
common, but optional wire to the device that's used by the program to tell the
device that it's talking to it. This is useful when multiple SPI devices are
connected to the same wires. Each device has a `CS` wire going to it and the
program sets the wire high to the device it wants. While the `CS` wire can be
any GPIO, most processors can automatically toggle the `CS` wire when making
SPI transactions.

When using `Circuits.SPI` on Linux and Nerves, `Circuits.SPI.open/2` uses the
Linux SPI device naming which includes the SPI bus number and chip select. For
example, the name `"spidev1.0"` refers to SPI bus 1 and CS0. All transactions
will automatically set CS0. Refer to your board or processor for SPI bus and CS
numbering.

The following shows an example Analog to Digital Converter (ADC) that reads
from either a temperature sensor on CH0 (channel 0) or a potentiometer on CH1
(channel 1). It converts the analog measurements to digital, and sends the
digital measurements to SPI pins on the main processor running Linux (e.g.
Raspberry Pi). Many processors, like the one on the Raspberry Pi, can't read
analog signals directly, so they need an ADC to convert the signal.

![SPI schematic](assets/images/schematic-adc.png)

The protocol for talking to the ADC in the example below is described in the
[MCP3002](http://www.microchip.com/wwwproducts/en/MCP3002) data sheet. The
protocol is very similar to an application program interface (API) for
software. It will tell you the position and function of the bits you will send
to the ADC, along with how the data (in the form of bits) will be returned.

See Figure 6-1 in the data sheet for the communication protocol. Sending a
`0x68` first reads the temperature and sending a `0x78` reads the
potentiometer. Since the data sheet shows bits, `0x68` corresponds to
`01101000b`.  The leftmost bit is the "Start" bit. The second bit is SGL/DIFF,
the third bit is ODD/SIGN, and the fourth bit is MSBF. From table 5-1, if
SGL/DIFF==1, ODD/SIGN==0, and MSBF==1 then that specifies channel 0 which is
connected to the thermometer.

```elixir
# Make sure that you've enabled or loaded the SPI driver or this will
# fail.
iex> {:ok, ref} = Circuits.SPI.open("spidev0.0")
{:ok, #Reference<...>}

# Read the potentiometer

# Use binary pattern matching to pull out the ADC counts (low 10 bits)
iex> {:ok, <<_::size(6), counts::size(10)>>} = Circuits.SPI.transfer(ref, <<0x78, 0x00>>)
{:ok, <<1, 197>>}

iex> counts
453

# Convert counts to volts (1023 = 3.3 V)
iex> volts = counts / 1023 * 3.3
1.461290322580645
```

As shown above, you'll find out that Elixir's binary pattern matching is
extremely convenient when working with hardware. More information can be
found in the [Kernel.SpecialForms documentation](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#%3C%3C%3E%3E/1)
and by running `h <<>>` at the IEx prompt.

## FAQ

### How do I only receive data?

SPI always sends a bit for every bit it receives. That means that to receive a
byte, you have to send a byte. Luckily, devices are designed with this in mind
and discard or ignore bytes in these situations. For example, if you have a
sensors and need to read 9 bytes of data, send 9 zeros to read it. The zeros
will be ignored and you'll get the data.

### How do I debug?

The most common issue is communicating with a SPI device for the first time.
First check that a SPI bus is available:

```elixir
iex> Circuits.SPI.bus_names()
["spidev0.0", "spidev0.1"]
```

If the list is empty, then a SPI bus is either not available, not enabled, or
not configured in the kernel. If you're using Raspbian, run `raspi-config` and
check that SPI is enabled in the advanced options. If you're on a BeagleBone,
try running `config-pin` and see the [Universal I/O
project](https://github.com/cdsteinkuehler/beaglebone-universal-io) to enable
the SPI pins. On other ARM boards, double check that SPI is enabled in the
kernel and that the device tree configures it.

### How do I set the speed of the SPI bus?

SPI bus options like frequency (`:speed_hz`) and bits per word (`:bit_per_word`)
are set as optional parameters to
[`Circuits.SPI.open/2`](https://hexdocs.pm/circuits_spi/Circuits.SPI.html#open/2).

For example, the following configures the SPI bus to run at 122,000 Hz:

```elixir
{:ok, my_spi} = Circuits.SPI.open("spidev0.0", speed_hz: 122000)`
```

The ability to set the bus speed is device-specific. Please verify with a logic
analyzer that the speed is actually being set and consult the documentation for
limitations.

### Where can I get help?

Many issues are unrelated to `Circuits.SPI`. If you expand your searches to
include Python and C forums, it's possible that someone else has run into your
problem too. SPI libraries in other languages should be similar to
`Circuits.SPI` so hopefully you'll find the answer.

If that fails, try posting a question to the [Elixir
Forum](https://elixirforum.com/). Tag the question with `Nerves` and it will
have a good chance of getting to the right people. Feel free to do this even if
you're not using Nerves.

### Can I develop code that uses Circuits.SPI on my laptop?

You have a few options:

1. Use the CircuitsSim backend
2. Create a custom backend and use it to mock interactions with the Circuits.SPI
   API

We hope to have support for USB adapters that have SPI interfaces in the future.

## License

This project follows the [REUSE recommendations](https://reuse.software).

All original source code in this project is licensed under Apache-2.0.
Exceptions to Apache-2.0 licensing are:

* Configuration and data files are licensed under CC0-1.0
* Documentation files are CC-BY-4.0
* Erlang Embedded board images are Solderpad Hardware License v0.51.
