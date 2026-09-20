# MC68000 v5 I/O DTACK Bring-Up

## Purpose and scope

This note adds I/O acknowledgement to the RAM/ROM/OVL memory-only DTACK circuit described in `RAM-ROM-OVL-BRINGUP.md`.

It preserves the current U11/U29 decode and reuses the existing unassigned gate sections before using any spare gates in U17, U26, U27, or U28. No additional logic IC is required.

The design acknowledges:

- ROM, RAM, and the U29 Y3 overlay-control page through the existing `/MEM_ACK` term;
- DUART only when the MC68681 asserts its active-low DTACK output;
- LCD immediately when `/CS_LCD` is asserted;
- RTC immediately when `/CS_RTC` is asserted.

The LCD and RTC immediate-acknowledge behavior must be verified against the device timing at the installed MC68000 clock frequency. Firmware must still comply with the LCD controller's busy-flag and command-execution timing requirements.

## Active-low acknowledge signals

Use these active-low inputs:

```text
/MEM_ACK        Existing U14A output: low for ROM, RAM, or OVL-control-page access
/DUART_ACK      MC68681 pin 9 DTACK output: low when the DUART accepts the cycle
/CS_LCD         U29 Y1: low when LCD is selected
/CS_RTC         U29 Y2: low when RTC is selected
```

`/DUART_ACK` is an open-drain MC68681 output. Fit a 4.7 kOhm pull-up resistor to `+5V` unless the net already has an explicit pull-up. Do not tie the DUART DTACK output directly to the MC68000 `/DTACK` pin.

The required equations are:

```text
/IO_ACK       = /DUART_ACK AND /CS_LCD AND /CS_RTC
/ACK_SELECT   = /MEM_ACK AND /IO_ACK
/DTACK        = /AS OR /ACK_SELECT
```

An inactive acknowledgement source is high. Consequently, the AND terms are low when any one valid source acknowledges a cycle.

## Step 1: retain and rename the current memory acknowledgement

The existing U14A logic produces a low output for:

- selected ROM;
- selected RAM; or
- selected U29 Y3 overlay-control page.

Rename its output net from `/ACK_SELECT` to:

```text
/MEM_ACK
```

Do not connect U14A pin 3 directly to U17A pin 2 after this change. The new I/O combiner drives `/ACK_SELECT`.

## Step 2: correct the DUART low-byte chip select

The existing U14B 74LS08 connection is not a valid active-low DUART
chip-select equation. An AND of `/CS_DUART` and `/LDS` goes low when
*either* input is low, so it selects IC1 on unrelated low-byte cycles.

Use the currently unused U8D 74LS32 section to generate a select that is
low only when both the DUART decoder output and the low-byte strobe are low:

```text
/DUART_CS = /CS_DUART OR /LDS
```

| Gate | Pin | Connect to |
|---|---:|---|
| U8D, 74LS32 | 12 | `/CS_DUART`, U29 pin 15 |
| U8D, 74LS32 | 13 | `/LDS` |
| U8D, 74LS32 | 11 | `/DUART_CS`, IC1 pin 35 |

Disconnect U14B pin 6 from the IC1 `/CS` net. If the optional D2 test LED
extension below is not fitted, tie its inputs, pins 4 and 5, to defined logic
levels and leave pin 6 open.

## Step 3: expose the DUART acknowledgement

Disconnect the obsolete U25C/U9F-derived `DUART_READY` path from the old DTACK circuit.

At MC68681 IC1:

| IC1 pin | Connect to | Notes |
|---:|---|---|
| 9, `DTACK` | `/DUART_ACK` | Active-low open-drain peripheral acknowledgement |

Add:

```text
R_DUART_DTACK: 4.7 kOhm from /DUART_ACK to +5V
```

The DUART drives `/DUART_ACK` low only after it has accepted a valid selected bus cycle. This allows the DUART to insert a wait state if needed.

## Step 4: combine DUART and LCD acknowledgement

Use U13A and U10A. These gate sections are existing chips and were disconnected from the old memory/I/O logic.

```text
DUART_OR_LCD = NAND(/DUART_ACK, /CS_LCD)
/DUART_LCD_ACK = NOT(DUART_OR_LCD)
```

| Gate | Pin | Connect to |
|---|---:|---|
| U13A, 74LS00 | 1 | `/DUART_ACK`, IC1 pin 9 |
| U13A, 74LS00 | 2 | `/CS_LCD`, U29 pin 14 |
| U13A, 74LS00 | 3 | `DUART_OR_LCD` |
| U10A, 74LS04 | 1 | `DUART_OR_LCD`, U13A pin 3 |
| U10A, 74LS04 | 2 | `/DUART_LCD_ACK` |

The result is low if either the DUART is ready or the LCD is selected.

## Step 5: add RTC acknowledgement

Use U13B and U10B.

```text
IO_ANY = NAND(/DUART_LCD_ACK, /CS_RTC)
/IO_ACK = NOT(IO_ANY)
```

| Gate | Pin | Connect to |
|---|---:|---|
| U13B, 74LS00 | 4 | `/DUART_LCD_ACK`, U10A pin 2 |
| U13B, 74LS00 | 5 | `/CS_RTC`, U29 pin 13 |
| U13B, 74LS00 | 6 | `IO_ANY` |
| U10B, 74LS04 | 3 | `IO_ANY`, U13B pin 6 |
| U10B, 74LS04 | 4 | `/IO_ACK` |

The result is low if the DUART is ready, the LCD is selected, or the RTC is selected.

## Step 6: combine memory and I/O acknowledgement

Use U25D and U10C.

```text
ACK_ANY = NAND(/MEM_ACK, /IO_ACK)
/ACK_SELECT = NOT(ACK_ANY)
```

| Gate | Pin | Connect to |
|---|---:|---|
| U25D, 74LS00 | 12 | `/MEM_ACK`, U14A pin 3 |
| U25D, 74LS00 | 13 | `/IO_ACK`, U10B pin 4 |
| U25D, 74LS00 | 11 | `ACK_ANY` |
| U10C, 74LS04 | 5 | `ACK_ANY`, U25D pin 11 |
| U10C, 74LS04 | 6 | `/ACK_SELECT` |

## Step 7: retain the final DTACK gate

Keep U17A as the final active-low acknowledgement gate:

```text
/DTACK = /AS OR /ACK_SELECT
```

| U17A pin | Connect to |
|---:|---|
| 1 | `/AS` |
| 2 | `/ACK_SELECT`, U10C pin 6 |
| 3 | `/DTACK` to the MC68000 |

Ensure no former U26C/U10B DTACK output is still connected to the `/DTACK` net.

## Optional Step 8: add D2 as a software-visible test LED

The current v5 schematic connects D2 to U29 Y7. Based on the actual decoder
inputs (`U11 A0-A2 = BA21-BA23` and `U29 A0-A2 = BA17-BA19`), Y7 is selected
by accesses in the `0x8E0000-0x8FFFFF` window. The source
`firmware\src\d2_flash.asm` uses `0x008E0000`.

D2 is directly driven by the active-low decoder output, not by a latch. It
lights only while Y7 is selected. Firmware therefore repeatedly accesses the
address during its on phase to produce visible average current.

First correct the LED polarity:

```text
+5V -> R18 -> D2 anode
D2 cathode -> U29 pin 7 (Y7), named /CS_LED
```

Then use the currently unused U14B 74LS08 to include `/CS_LED` in the I/O
acknowledgement:

```text
/IO_ACK_WITH_LED = /IO_ACK AND /CS_LED
```

| Gate or pin | Connect to |
|---|---|
| U14B, 74LS08 pin 4 | `/IO_ACK`, U10B pin 4 |
| U14B, 74LS08 pin 5 | `/CS_LED`, U29 pin 7 |
| U14B, 74LS08 pin 6 | `/IO_ACK_WITH_LED` |
| U25D, 74LS00 pin 13 | `/IO_ACK_WITH_LED`, U14B pin 6 |

Remove the previous direct U10B pin 4 to U25D pin 13 connection. This change
does not alter DUART, LCD, or RTC acknowledgement: an assertion from any of
those sources still makes `/IO_ACK_WITH_LED` low. It adds immediate
acknowledgement for the LED-select access so the CPU does not wait forever.

Do not use the `0x500000`-series labels previously drawn near U29 for firmware
addresses. They do not match the decoder address-bit connections in the saved
v5 schematic.

## Expected truth table

Assume `/AS=0` during each valid cycle.

| Access | `/MEM_ACK` | `/IO_ACK` | `/ACK_SELECT` | `/DTACK` |
|---|---:|---:|---:|---:|
| ROM | 0 | 1 | 0 | 0 |
| RAM | 0 | 1 | 0 | 0 |
| OVL-control page | 0 | 1 | 0 | 0 |
| DUART, before it responds | 1 | 1 | 1 | 1 |
| DUART, DTACK asserted | 1 | 0 | 0 | 0 |
| LCD selected | 1 | 0 | 0 | 0 |
| RTC selected | 1 | 0 | 0 | 0 |
| D2 selected, optional Step 8 fitted | 1 | 0 | 0 | 0 |
| Unmapped address | 1 | 1 | 1 | 1 |

## Gates intentionally left in reserve

After this I/O acknowledgement implementation, do not repurpose the following gates until the board is working and their original/unused state has been checked:

```text
U17B, U17C, U17D
U26A, U26C
U27A, U27B, U27C, U27D
U28A, U28B, U28C, U28D
```

Tie inputs of gates that are made unused by this rework to a defined logic level. Do not leave TTL inputs floating.

## Bring-up sequence

1. Verify ROM reset-vector fetches, high-ROM execution, software OVL clear, and RAM read/write with the I/O combiner disconnected or `/IO_ACK` held high.
2. Fit the DUART DTACK pull-up and connect `/DUART_ACK` through U13A/U10A.
3. Capture `/AS`, `/DTACK`, `/CS_DUART`, IC1 pin 9, and `R/W` on the logic analyzer. Confirm `/DTACK` remains high until the DUART pulls `/DUART_ACK` low.
4. Connect LCD acknowledgement, then verify `/CS_LCD` and `/DTACK` timing.
5. Connect RTC acknowledgement, then verify `/CS_RTC` and `/DTACK` timing.
6. Do not test unmapped locations without a reset method available; the CPU correctly waits forever when no acknowledgement source is active.
