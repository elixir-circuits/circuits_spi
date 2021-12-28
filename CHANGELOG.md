# Changelog

## v1.1.0 - 10-20-2021

* Updates
  * Add `max_transfer_size/0` to return the low level maximum size that can be
    sent at a time. Thanks to @cocoa-xu for this.

* Bug fixes
  * Properly mark NIF transfer function as IO bound so that the Erlang scheduler
    schedules it properly.

## v1.0.0 - 10-20-2021

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
