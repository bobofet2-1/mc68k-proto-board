# TTL overlay implementation

| Ref | Part | Role |
|---|---|---|
| U29 Y3 | existing 74LS138 output | `/CS_BOOTCTL`, spare I/O-region select |
| U50A | 74LS74 | reset-set, write-cleared `OVL` state |
| U51/U52 | 74LS32 | active-low write qualification |
| U53 | 74LS04 | positive clock pulse for U50A |

U50A pin use: `~CLR` (1) = +5 V, `D` (2) = GND, `CLK` (3) =
`BOOTCTL_WR`, `~PRE` (4) = `/RESET`, `Q` (5) = `OVL`, `~Q` (6) = `OVL_N`,
pin 7 = GND, pin 14 = +5 V. Tie unused gates and the unused U50B flip-flop
inputs to defined levels before layout.

The new `OVL` net belongs on the enable side of the ROM-alias TTL select:
asserted selects boot ROM at zero; deasserted selects RAM. Do not use
`/RESET` itself as a ROM-select term, and do not clock U50 from an unqualified
address decoder output.
