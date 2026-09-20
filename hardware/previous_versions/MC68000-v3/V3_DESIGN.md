# MC68000 v3 TTL boot overlay

v3 is an independent copy of the original board and uses only 5 V TTL. There
is no GAL, ATF, CPLD, JEDEC file, or programmable-logic interface.

## Boot-overlay state

U50A is a 74LS74. `/RESET` drives its active-low preset, so reset sets `OVL=1`
before the CPU starts. Its `D` input is grounded and its clear input is tied
high. A valid boot-control write produces one rising `BOOTCTL_WR` edge at
U50A's clock input, changing `OVL` to zero. With `D=0`, it stays zero until
the next hardware reset. This is deliberately a data state, not a gated clock.

`OVL` is the enable-side control for the ROM-alias select in the memory TTL
tree. A 74LS138 enable can gate that select, but cannot remember a software
write; the 74LS74 is required for the state. The memory gate must select ROM
at zero while `OVL=1`, and RAM at zero when `OVL=0`; permanent top-ROM decode
is unaffected.

## Write-only BOOTCTL address

Software disables the overlay by any byte or word write to **`0x860000`**.
The register is write-only; read values are unspecified. The simple existing
TTL decode deliberately aliases this write address:

```text
/CS_BOOTCTL = active when
  BA23..BA21 = 100       (U11 /I/O output, gated by /AS)
  BA19..BA17 = 011       (U29 Y3, the previously unused 74LS138 output)
```

`BA20` and `BA16..BA0` are not decoded, so the same write is mirrored over
`0x860000–0x87FFFF` and `0x960000–0x97FFFF`. Firmware must use `0x860000`;
the mirrors are a documented consequence of retaining the simple TTL decode,
not additional registers. U29 Y0–Y2 remain the existing DUART/LCD/RTC
selects, so Y3 is non-conflicting in the source schematic.

U51 and U52 (74LS32 stages) form
`BOOTCTL_WR_N = /CS_BOOTCTL OR R/W OR /AS`. U53 (74LS04) inverts it, producing
the positive clock edge only for an active control-window write. Address and
`R/W` are stable before `/AS` asserts, so address changes while `/AS` is idle
cannot create a clock edge.

## Source-document correction

The previous address note's `0x500000` I/O assumptions do not match the
original schematic's U11/U29 wiring. This v3 document follows the actual
source wiring above. It also replaces the old automatic final-vector overlay
release: v3 keeps boot ROM visible until firmware explicitly writes BOOTCTL.
