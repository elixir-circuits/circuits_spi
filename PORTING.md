<!--
  SPDX-License-Identifier: CC-BY-4.0
  SPDX-FileCopyrightText: 2018 Frank Hunleth
-->

# Porting

## Upgrading Circuits.SPI 1.x projects to 2.0

Circuits.SPI 2.0 supports alternative SPI hardware and the ability to mock or
emulate devices via backends. The Linux spi-dev backend is the default and this
matches Circuits.SPI 1.x. Most projects won't need any changes other than to
update the dependency in `mix.exs`. If upgrading a library, The following
dependency specification is recommended to allow both `circuits_i2c` versions:

```elixir
   {:circuits_spi, "~> 2.0 or ~> 1.0"}
```

The following potentially breaking changes were made:

1. `Circuits.SPI.open/1` no longer accepts Erlang strings.
2. The `stub` implementation has been renamed to `spi_dev_test`. If using the
   stub implementation for testing, you may have to update your tests since
   there were minor changes.

## Upgrading Elixir/ALE projects to Circuits.SPI

The `Circuits.SPI` package is the next version of Elixir/ALE's SPI support.
If you're currently using Elixir/ALE, you're encouraged to switch. Here are some
benefits:

1. Supported by both the maintainer of Elixir/ALE and a couple others. They'd
   prefer to support `Circuits.SPI` issues.
2. Much faster than Elixir/ALE.
3. Simplified API

`Circuits.SPI` uses Erlang's NIF interface. NIFs have the downside of being able
to crash the Erlang VM. Experience with Elixir/ALE has given many of us
confidence that this won't be a problem.

### Code modifications

`Circuits.SPI` is not a `GenServer`, so if you've added `ElixirALE.SPI` to a
supervision tree, you'll have to take it out and manually call
`Circuits.SPI.open` to obtain a reference. A common pattern is to create a
`GenServer` that is descriptive of what the SPI device does and have it be
responsible for all SPI calls.

The remain modifications should mostly be mechanical:

1. Rename references to `ElixirALE.SPI` to `Circuits.SPI` and `elixir_ale`
   to `circuits_spi`
2. Change calls to `ElixirALE.SPI.start_link/2` to `Circuits.SPI.open/1`.
   Review the arguments to open to not include any `GenServer` options.
3. The `transfer` function now returns `{:ok, result}` tuples on
   success so add code to handle that.
4. Consider adding a call to `Circuits.SPI.close/1` if there's an obvious place
   to release the SPI bus. This is not strictly necessary since the garbage
   collector will free unreferenced SPI references.
5. Change calls to `ElixirALE.SPI.device_names/0` to `Circuits.SPI.bus_names/0`.

If you find that you have to make any other changes, please let us know via an
issue or PR so that other users can benefit.
