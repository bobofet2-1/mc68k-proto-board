# MC68000 Address Decode and Reset Overlay

## Status

Reviewed design specification for the address-decoder redesign. The active schematic to implement it is `hardware\MC68000\MC68000.kicad_sch`.

## Hardware facts

| Devices | Wiring | Usable organization |
|---|---|---|
| U15, U16: 28C256 | `BA1–BA15` and one byte lane per device | 32K x 16-bit = 64 KiB |
| U12, U20: 628128 | `BA1–BA17` and one byte lane per device | 128K x 16-bit = 256 KiB |

This design retains the workbook's 128 KiB RAM allocation. Therefore, it uses the lower 64K words of the installed SRAM pair; `BA17` must be zero for an active RAM select. The unused upper 128 KiB is reserved for a future RAM expansion.

The MC68000 address bus is byte addressed. The memory-device address pins use the corresponding word-address lines: CPU `BA1` maps to device `A0`, CPU `BA2` to device `A1`, and so on. The low-byte and high-byte devices are selected independently through `/LDS` and `/UDS`.

## Final memory map

| Byte-address range | Size | Selection |
|---|---:|---|
| `0x000000–0x000007` | 8 B | Reset overlay: ROM while `OVL=1`, RAM when `OVL=0` |
| `0x000008–0x01FFFF` | 128 KiB - 8 B | RAM |
| `0x500000–0x50003F` | 64 B | DS12887 RTC |
| `0x500040–0x50004F` | 16 B | MC68681 DUART |
| `0xFF0000–0xFFFFFF` | 64 KiB | U15/U16 ROM pair |

All locations not listed are reserved or unmapped. Existing LCD and other I/O ranges must retain their documented addresses when their select equations are migrated to the new decoder.

## Select conditions

Use byte-address bits `A23..A0` below; `AS_ACTIVE`, `UDS_ACTIVE`, and `LDS_ACTIVE` mean that the respective active-low CPU signal is asserted.

```text
ROM_TOP       = (A23..A16 == 0xFF)
RAM_WINDOW    = (A23..A17 == 0b0000000)
VECTOR_8      = (A23..A3  == 0)
ROM_ALIAS     = OVL AND VECTOR_8

ROM_SELECT    = ROM_TOP OR ROM_ALIAS
RAM_SELECT    = RAM_WINDOW AND NOT ROM_ALIAS

CS_ROM_L      = ROM_SELECT AND LDS_ACTIVE
CS_ROM_H      = ROM_SELECT AND UDS_ACTIVE
CS_RAM_L      = RAM_SELECT AND LDS_ACTIVE
CS_RAM_H      = RAM_SELECT AND UDS_ACTIVE
```

Gate each select with the board's existing address-strobe/read-write timing in the same manner as the present design. The equations above describe the address ownership; they do not replace the EEPROM `/OE`, EEPROM `/WE`, SRAM `/OE`, or SRAM `/WE` timing logic.

## Reset overlay state machine

The MC68000 reads the reset vectors as four 16-bit bus cycles:

| Cycle | Address | Contents |
|---:|---|---|
| 1 | `0x000000` | Initial SSP bits `31:16` |
| 2 | `0x000002` | Initial SSP bits `15:0` |
| 3 | `0x000004` | Initial PC bits `31:16` |
| 4 | `0x000006` | Initial PC bits `15:0` |

Implement `OVL` with a reset-set flip-flop:

1. Assert `/PRE` while `/RESET` is low so `OVL=1` before the processor can fetch the vectors.
2. Feed `D = OVL AND NOT VECTOR_LAST` to the flip-flop.
3. Decode `VECTOR_LAST = (A23..A3 == 0) AND (A2..A1 == 0b11)`. This identifies the word at `0x000006`; `A0` is not used by a word-aligned MC68000 bus cycle.
4. Clock the flip-flop directly from the rising edge of `/AS`. On the first three vector cycles, `VECTOR_LAST=0` and the feedback keeps `OVL=1`. On the final cycle, `VECTOR_LAST=1` and the flip-flop stores zero. `/AS` rises only after the processor has completed that transfer, so the ROM remains selected until the final word's data is valid and sampled.
5. Once `OVL=0`, the feedback keeps `D=0`, preventing later bus cycles from re-enabling the alias. Only the next hardware reset can set it again.

This direct-clock arrangement avoids a gated-clock false edge if the address changes while `/AS` is idle. Use the remaining half of the flip-flop package with all inputs tied to defined levels. Do not use `/RESET` directly as a ROM-select term: it is released before vector fetches occur.

## ROM image requirements

The initial SSP value at ROM offsets `0x000000–0x000003` must identify valid RAM. The initial PC at offsets `0x000004–0x000007` must point to permanent ROM, for example `0xFF0008`; it must not point at the zero-page alias because that alias is removed after the final vector read. Place boot code at the corresponding permanent ROM offset.

## Implementation and review checklist

1. Replace the current `BA21–BA23` partial decode with the predicates above, using appropriate cascaded TTL decode logic.
2. Add the overlay flip-flop, final-vector qualifier, reset preset, and named `OVL`, `ROM_ALIAS`, `ROM_TOP`, and `RAM_WINDOW` nets.
3. Retain the current I/O and `/DTACK` timing while narrowing their address selects to their documented windows.
4. Run KiCad ERC and inspect the generated netlist.
5. Verify the four reset reads, normal RAM accesses at `0x000000` and `0x01FFFF`, ROM accesses at `0xFF0000` and `0xFFFFFF`, and each I/O select.
