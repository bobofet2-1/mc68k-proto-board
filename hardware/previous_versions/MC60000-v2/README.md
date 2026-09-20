# MC60000-v2

This is an isolated KiCad project copy created from `hardware\MC68000` for the address-decoder redesign. The original project has not been modified.

The reviewed decoder specification is in:

`..\..\docs\design\01-address\README.md`

The specification defines:

- 128 KiB RAM at `0x000000-0x01FFFF`;
- the 64 KiB U15/U16 ROM pair at `0xFF0000-0xFFFFFF`;
- a reset-set ROM alias for `0x000000-0x000007`; and
- an `/AS`-clocked, one-way overlay release after the vector word at `0x000006`.

`erc-baseline.rpt` is the copied schematic's initial KiCad 10 ERC report. It records 533 pre-existing violations and is a baseline only; it is not evidence that the redesigned decoder is electrically verified.
