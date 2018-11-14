# Porting Elixir/ALE to Circuits.SPI

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

## Code modifications

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
