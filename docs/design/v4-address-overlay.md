# v4 address decode and overlay design note

## Page architecture

`MC68000.kicad_sch` is the root page. It retains the CPU, memory, U11 boot
alias, and a real hierarchical sheet named `Address Decode`. The child sheet
is `hardware/MC68000-v4/address-decode.kicad_sch`; it contains U29, U32A,
and the overlay hand-off gates. Named global labels are the intentional
electrical connections between the two pages.

U11 continues to provide the coarse boot alias. This is deliberately not a
permanent address decode: while `OVL=1`, the ROM alias may be visible from
`0x000000` through `0x1FFFFF`. Software must leave the alias before relying
on low RAM.

## Reserved control page and software API

U29 is an active-low 74LS138 I/O page decoder. With the existing U29 input
polarities and labels, its unused Y3 output, pin 12, selects exactly:

```text
0x530000-0x53FFFF
```

This page is reserved and intentionally unmapped. It is not a readable
register. The complete API is:

```text
write any byte or word in 0x530000-0x53FFFF: disable the boot overlay
read from the page: no overlay state change
```

Software must not allocate this page to a peripheral.

## Overlay state and hand-off

`/RESET` asynchronously presets U32A so `OVL=1` before reset-vector fetch.
The rising edge of `/AS` is connected directly to U32A's clock. No gated
clock is used. The D feedback holds `OVL` high except when both conditions
are true: U29 Y3 is asserted and `R/W=0`. A write in the reserved page then
clocks zero into U32A. The cleared state feeds back and is permanent until
the next reset.

The previous scheme used U33-U35, three 74LS688 8-bit equality comparators,
to verify all 24 address bits of exact write address `0x500050`. A 74LS688
compares two 8-bit values for equality. Those comparators and their
exact-address logic were removed because the reserved page gives a simpler,
documented interface without requiring a 24-bit equality test. No 74LS688
remains in v4: U38 is an 8-input NAND high-ROM decoder, while U50-U52 use
ordinary TTL gates for the low-RAM predicate.

## Memory maps

```text
Reset boot:   U11 coarse ROM alias at 0x000000-0x1FFFFF while OVL=1
Permanent:    RAM 0x000000-0x01FFFF
              ROM 0xFF0000-0xFFFFFF
```

The reset-vector PC must be a permanent high-ROM address, such as
`0xFF0008`, rather than a low alias address.
