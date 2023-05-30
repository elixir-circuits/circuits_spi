# Changelog

## v2.0.0-pre.0 - 2022-05-30

This is a major update to Circuits.SPI that removes the requirement to use
Nerves or Linux. The API is almost the same and the default is to compile and
use the Linux backend, so changes may not be needed.

This is a prerelease so APIs may still change before the v2.0.0 release.

* Changes
  * Support alternative backends for different operating systems or for
    simulated hardware
  * Defer loading the Linux NIF until `Circuits.SPI.open/2` is called

## v1.4.0 - 2022-12-31

* Changes
  * Remove Erlang convenience functions since no one used them
  * Require Elixir 1.10 or later. Previous versions probably work, but won't be
    supported. This opens up the possibility of using Elixir 1.10+ features in
    future releases.

## v1.3.0 - 2022-02-21

* Updates
  * Add `transfer!/2`. This function is the raising version of `transfer/2`.
    Thanks to @mnishiguchi for this.

## v1.2.0 - 2022-01-23

* Updates
  * Add the `:lsb_first` option to support SPI transfers that send the least
    significant bit first rather than the most significant one. If the bit
    reversal isn't supported by the hardware, a software version is used.
  * Add `config/1` to return the configuration for an SPI bus reference. This is
    useful for checking what is actually being used.
  * Update `transfer/2` to support `iodata`. This makes the interface more
    convenient since now you can prepend SPI message headers in your code
    without having to concatenate binaries.
  * Support full pathes being passed to SPI devices in `open/2`. Previously this
    resulted in errors, but it was easy to forget.

## v1.1.0 - 2021-12-28

* Updates
  * Add `max_transfer_size/0` to return the low level maximum size that can be
    sent at a time. Thanks to @cocoa-xu for this.

* Bug fixes
  * Properly mark NIF transfer function as IO bound so that the Erlang scheduler
    schedules it properly.

## v1.0.0 - 2021-10-20

This release only changes the version number. No code has changed.

## v0.1.6

This release only has doc and build output cleanup. No code has changed.

## v0.1.5

* Bug fixes
  * Add -fPIC to compilation flags to fix build with `nerves_system_x86_64` and
    other environments using the Musl C toolchains

## v0.1.4

This release doesn't functionally change any code. The only updates are to build
files for consistency with other Circuits projects.

## v0.1.3

* Bug fixes
  * Fix binary handling in NIF. This fixes segfaults and other errors on
    Raspbian.

## v0.1.2

* Bug fixes
  * Fix file handle leak when SPI bus references were garbage collected.

## v0.1.1

* Bug fixes
  * Build C source under the `_build` directory so that changing targets
    properly rebuilds the C code as well as the Elixir code.

## v0.1.0

Initial release to hex.
