# MC68000 v4 - Address Decode and Boot Overlay

The address decode and boot-overlay logic is on schematic sheet 2,
`address-decode.kicad_sch`. The root sheet contains the CPU, memory, and the
hierarchical sheet symbol. Inter-sheet signals use explicitly named global
labels.

## Maps

After hand-off, RAM occupies `0x000000-0x01FFFF` and ROM occupies
`0xFF0000-0xFFFFFF`.

During reset boot, U11 permits its existing coarse low-ROM alias while
`OVL=1`. The alias can extend through `0x000000-0x1FFFFF`; this transient
mirror is intentional and must not be used as a permanent map. RAM is
inhibited during the low 128 KiB portion of that alias. The reset-vector PC
must point into permanent high ROM, for example `0xFF0008`.

## Overlay-control API

U29 is the existing I/O 74LS138 decoder. Its active-low Y3 output (pin 12)
decodes `0x530000-0x53FFFF`. This entire page is intentionally reserved and
unmapped except for overlay control:

```text
write any byte or word to 0x530000-0x53FFFF -> permanently disable OVL
```

Reads have no effect. The page must not be assigned to a peripheral.

`/RESET` asynchronously presets U32A, setting `OVL` before vector fetch.
U32A clocks on the rising edge of `/AS` directly; the clock is not gated.
Its D feedback holds `OVL` high unless the cycle is a write (`R/W=0`) to
U29 Y3. That qualifying write clocks zero into U32A. Only reset can restore
the overlay.

The former U33-U35 74LS688 comparators recognized exact address `0x500050`
by comparing all 24 address bits. No 74LS688 remains in v4. U38 is now an
8-input NAND high-ROM decoder, and the small U50-U52 TTL gate network
decodes the low RAM window. The page decode is simpler, reserves a clearly
documented I/O page, and does not use a gated clock.
