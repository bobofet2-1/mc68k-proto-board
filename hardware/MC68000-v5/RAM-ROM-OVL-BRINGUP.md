# MC68000 v5 RAM, ROM, OVL, and DTACK Bring-Up

## Scope

This is the minimum-chip-count memory bring-up design.

- Keep U11 and U29 as the existing 74LS138 address decoders.
- Repurpose the indicated gate sections in the existing 74LS00, 74LS04, 74LS08, and 74LS32 packages.
- Add only U32, a 74LS74, and its 100 nF local bypass capacitor.
- Acknowledge ROM, RAM, and the overlay-control page only.
- Do not connect DUART, LCD, RTC, or other I/O into `/DTACK` until reset-vector reads, permanent-ROM execution, overlay handoff, and RAM reads/writes work.

The existing physical chips remain installed. "Repurpose" means disconnecting an old gate-level function and using that gate section for the function in this document.

## Approved overlay equations

Use the raw active-low U11 outputs:

```text
/LOW_WIN  = U11 pin 15, O0
/HIGH_WIN = U11 pin 7, O7
```

The existing U29 Y3 output is the active-low software overlay-control page:

```text
/OVL_CONTROL_PAGE = U29 pin 12, Y3
```

The required logic equations are:

```text
OVL_KEEP          = /OVL_CONTROL_PAGE OR R/W
OVL_D             = OVL AND OVL_KEEP

/LOW_ROM_ALIAS    = /LOW_WIN OR /OVL
/ROM_SELECT       = /HIGH_WIN AND /LOW_ROM_ALIAS
/RAM_SELECT       = NAND(LOW_WIN, /OVL)

/CS_ROM_L         = NAND(ROM_SELECT, LDS)
/CS_ROM_H         = NAND(ROM_SELECT, UDS)
/CS_RAM_L         = /RAM_SELECT OR /LDS
/CS_RAM_H         = /RAM_SELECT OR /UDS

MEM_READY         = NAND(/ROM_SELECT, /RAM_SELECT)
/MEMORY_DTACK     = NOT(MEM_READY)
/ACK_SELECT       = /MEMORY_DTACK AND /OVL_CONTROL_PAGE
/DTACK            = /AS OR /ACK_SELECT
```

Here `LOW_WIN`, `ROM_SELECT`, `LDS`, and `UDS` without a slash are the active-high inverses of their active-low counterparts.

## U32: the only new logic package

Install a 74LS74 as U32. Use flip-flop A for overlay state.

| U32A pin | Net | Purpose |
|---:|---|---|
| 1, `/CLR` | `+5V` | Keep asynchronous clear inactive |
| 2, `D` | `OVL_D` | Next overlay state |
| 3, `CLK` | `/AS` | Direct clock; do not gate this clock |
| 4, `/PRE` | `/RESET` | Reset presets `OVL=1` |
| 5, `Q` | `OVL` | High while the low ROM alias is enabled |
| 6, `/Q` | `/OVL` | Low while the low ROM alias is enabled |
| 7 | GND | Supply |
| 14 | `+5V` | Supply |

Fit a 100 nF ceramic capacitor directly between U32 pins 14 and 7.

Tie every unused U32B input to a defined logic level. Do not leave TTL inputs floating.

## Gate reassignment and pin wiring

Before moving a signal, remove the old wire and net label from that gate pin. Do not connect two TTL outputs together.

### OVL state logic

| Gate | Pin | Connect to |
|---|---:|---|
| U18C, 74LS32 | 9 | `/OVL_CONTROL_PAGE`, U29 pin 12 |
| U18C, 74LS32 | 10 | CPU `R/W` |
| U18C, 74LS32 | 8 | `OVL_KEEP` |
| U14D, 74LS08 | 12 | `OVL`, U32A pin 5 |
| U14D, 74LS08 | 13 | `OVL_KEEP`, U18C pin 8 |
| U14D, 74LS08 | 11 | `OVL_D`, U32A pin 2 |

The page is harmless on reads because `R/W=1` keeps `OVL_D=OVL`. A write in the page drives `OVL_D=0`; the rising edge of `/AS` clocks the zero into U32A. Only the next reset can set `OVL` again.

### ROM window selection

| Gate | Pin | Connect to |
|---|---:|---|
| U18D, 74LS32 | 12 | `/LOW_WIN`, U11 pin 15 |
| U18D, 74LS32 | 13 | `/OVL`, U32A pin 6 |
| U18D, 74LS32 | 11 | `/LOW_ROM_ALIAS` |
| U14C, 74LS08 | 9 | `/HIGH_WIN`, U11 pin 7 |
| U14C, 74LS08 | 10 | `/LOW_ROM_ALIAS`, U18D pin 11 |
| U14C, 74LS08 | 8 | `/ROM_SELECT` |

`/ROM_SELECT` is active for permanent high ROM at all times and for the low-address ROM alias only while `OVL=1`.

### RAM window selection

| Gate | Pin | Connect to |
|---|---:|---|
| U10D, 74LS04 | 9 | `/LOW_WIN`, U11 pin 15 |
| U10D, 74LS04 | 8 | `LOW_WIN` |
| U26D, 74LS00 | 12 | `LOW_WIN`, U10D pin 8 |
| U26D, 74LS00 | 13 | `/OVL`, U32A pin 6 |
| U26D, 74LS00 | 11 | `/RAM_SELECT` |

At reset `/OVL=0`, so `/RAM_SELECT=1` and RAM is disabled. After the control-page write, `/OVL=1`, so `/RAM_SELECT` follows the low U11 window.

### ROM byte-lane selects

Disconnect the old U25A/U25B to U14C/U14D ROM lane path. U14C and U14D are now used above. Move the final ROM chip-select labels to U25A and U25B.

| Gate | Pin | Connect to |
|---|---:|---|
| U10E, 74LS04 | 11 | `/ROM_SELECT`, U14C pin 8 |
| U10E, 74LS04 | 10 | `ROM_SELECT` |
| U10F, 74LS04 | 13 | `/LDS` |
| U10F, 74LS04 | 12 | `LDS` |
| U9B, 74LS04 | 3 | `/UDS` |
| U9B, 74LS04 | 4 | `UDS` |
| U25A, 74LS00 | 1 | `ROM_SELECT`, U10E pin 10 |
| U25A, 74LS00 | 2 | `LDS`, U10F pin 12 |
| U25A, 74LS00 | 3 | `/CS_ROM_L` |
| U25B, 74LS00 | 4 | `ROM_SELECT`, U10E pin 10 |
| U25B, 74LS00 | 5 | `UDS`, U9B pin 4 |
| U25B, 74LS00 | 6 | `/CS_ROM_H` |

This selects both EEPROMs for a 16-bit access, or only the applicable EEPROM for a byte access.

### RAM byte-lane selects

Disconnect the old inputs to U18A and U18B. Keep their output labels, but drive them with the new inputs below.

| Gate | Pin | Connect to |
|---|---:|---|
| U18A, 74LS32 | 1 | `/RAM_SELECT`, U26D pin 11 |
| U18A, 74LS32 | 2 | `/LDS` |
| U18A, 74LS32 | 3 | `/CS_RAM_L` |
| U18B, 74LS32 | 4 | `/RAM_SELECT`, U26D pin 11 |
| U18B, 74LS32 | 5 | `/UDS` |
| U18B, 74LS32 | 6 | `/CS_RAM_H` |

## Memory-only DTACK

Disconnect the existing U17A memory inputs, disconnect U17A pin 3 from the old U17D path, and disconnect the former U26C/U10B DTACK output from the `/DTACK` net.

Reuse U13C/U13D to create a memory acknowledge, U14A to include the software control page, and U17A as the final DTACK gate.

| Gate | Pin | Connect to |
|---|---:|---|
| U13C, 74LS00 | 9 | `/ROM_SELECT`, U14C pin 8 |
| U13C, 74LS00 | 10 | `/RAM_SELECT`, U26D pin 11 |
| U13C, 74LS00 | 8 | `MEM_READY` |
| U13D, 74LS00 | 12 | `MEM_READY`, U13C pin 8 |
| U13D, 74LS00 | 13 | `MEM_READY`, U13C pin 8 |
| U13D, 74LS00 | 11 | `/MEMORY_DTACK` |
| U14A, 74LS08 | 1 | `/MEMORY_DTACK`, U13D pin 11 |
| U14A, 74LS08 | 2 | `/OVL_CONTROL_PAGE`, U29 pin 12 |
| U14A, 74LS08 | 3 | `/ACK_SELECT` |
| U17A, 74LS32 | 1 | `/AS` |
| U17A, 74LS32 | 2 | `/ACK_SELECT`, U14A pin 3 |
| U17A, 74LS32 | 3 | `/DTACK` |

The resulting memory-only timing is:

| Access | `/ROM_SELECT` | `/RAM_SELECT` | `/OVL_CONTROL_PAGE` | `/DTACK` while `/AS=0` |
|---|---:|---:|---:|---:|
| ROM | 0 | 1 | 1 | 0 |
| RAM | 1 | 0 | 1 | 0 |
| Overlay-control page | 1 | 1 | 0 | 0 |
| Unmapped | 1 | 1 | 1 | 1 |

## Gates no longer used for their original memory function

The following old paths must not remain connected to the new nets:

- the original U14C/U14D outputs must no longer drive `/CS_ROM_L` or `/CS_ROM_H`;
- the original U25A/U25B ROM-lane path must be removed before those gates are reassigned;
- the original U13C/U13D RAM-lane path must be removed before those gates are reassigned;
- the former ROM and RAM selection outputs from the old U26A/U25D path must be isolated from `/ROM_SELECT` and `/RAM_SELECT`;
- the original U17A to U17D memory DTACK path and the U26C/U10B `/DTACK` output must be isolated.

Rename intentionally retained legacy signals with an `OLD_` prefix or place no-connect markers on unused gate outputs. Tie any newly unused TTL gate inputs to a defined level.

## Bring-up order

1. Hold OVL enabled and verify ROM supplies reset vectors at low address.
2. Verify the reset PC is a permanent high-ROM address, for example `0xFF0008`.
3. Verify high-ROM instruction fetches receive `/DTACK`.
4. Write to the U29 Y3 overlay-control page and verify `OVL` changes from high to low on the rising edge of `/AS`.
5. Verify a low-address RAM read/write asserts only the matching RAM byte lane and receives `/DTACK`.
6. Add DUART, LCD, RTC, and other I/O acknowledgement only after these memory tests work.
