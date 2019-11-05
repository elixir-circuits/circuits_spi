# Changelog

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
