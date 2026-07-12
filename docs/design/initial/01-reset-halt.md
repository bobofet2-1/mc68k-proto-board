Here's a complete circuit design. Key MC68000 facts first: both /RESET (pin 18) and /HALT (pin 17) are bidirectional open-drain — the CPU can assert them, and so can you. A proper power-on reset requires both
lines asserted LOW for ≥100ms.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Circuit Architecture

 +5V ──┬── R1 (4.7kΩ) ──────────────────────── /RESET (pin 18) ──┬─────────────────────────────────────┐
       │                                                           │                                     │
       └── R2 (4.7kΩ) ──────────────────────── /HALT  (pin 17) ──┼──[R6 470Ω]──[LED1 Blue]──+5V        │
                                                                   │                                     │
                         ┌────────────────────────────────────────┘                                     │
                         │ RESET BUS (open-drain, drives both lines)                                    │
                         │                                                                               │
             ┌───────────┴───────────────────────────────────────┐                                      │
             │                                                   │                                      │
      [DS1813-5]                                        Q1 (2N3904 NPN)                                 │
       VCC─+5V                                          Collector ─── RESET BUS                        │
       GND─GND                                          Emitter  ─── GND                               │
       /RST─RESET BUS                                   Base ─── R5 (1kΩ) ─── U1B out                  │
       (open-drain, 150ms pulse)                                                                        │
                                                    [74HC14 — two inverters]                           │
                                               U1A in ─── node A ─── U1A out ─── U1B in ─── U1B out    │
                                                    │                                                   │
                                               R4 (10kΩ)─+5V   C2 (1µF)─GND   SW1─GND                │
                                                    └─────────────────────────────────────────────────┘
                                                     (RC debounce: τ = 10ms, covers switch bounce)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Block-by-Block Explanation

1. Pull-ups

 - R1
  4.7kΩ on /RESET, R2 4.7kΩ on /HALT — required since both are open-drain
 - Without these the lines float and the CPU won't start

2. Power-On Reset — DS1813-5 (SOT-23)

┌─────────────────────┬─────────────────────────────────────────┐
│ Feature             │ Value                                   │
├─────────────────────┼─────────────────────────────────────────┤
│ Monitored voltage   │ 5V rail (threshold ~4.65V)              │
├─────────────────────┼─────────────────────────────────────────┤
│ Reset pulse width   │ 150ms (meets 100ms MC68000 requirement) │
├─────────────────────┼─────────────────────────────────────────┤
│ Output type         │ Open-drain active-LOW                   │
├─────────────────────┼─────────────────────────────────────────┤
│ Output connected to │ Both /RESET and /HALT                   │
└─────────────────────┴─────────────────────────────────────────┘

 - Drives both lines LOW cleanly on every power-up
 - Also re-triggers if +5V droops below threshold (brownout protection)
 - SOT-23: pin 1=GND, pin 2=VCC, pin 3=/RST out
 - Alternative: MCP130T-450I/TO (TO-92, easier to hand-solder, 200ms pulse)

3. Manual Reset — Debounced Switch

Debounce: R4 (10kΩ) + C2 (1µF) + U1A 74HC14 Schmitt trigger

 - Time constant τ = 10ms — eliminates bounce on press and release
 - Schmitt trigger hysteresis gives clean digital edge from the RC waveform

Open-drain drive: U1B (second 74HC14 gate, non-inverting pair) drives base of Q1 (2N3904)

 - SW1 open → U1A input HIGH → U1B output LOW → Q1 off → /RESET floats HIGH ✓
 - SW1 pressed → U1A input LOW → U1B output HIGH → Q1 saturates → both /RESET and /HALT pulled LOW ✓
 - When CPU asserts /RESET itself (e.g. RESET opcode): Q1 is off, no contention ✓

Why the NPN transistor? The 74HC14 is push-pull. If you wire it directly to /RESET, its HIGH output fights the CPU's open-drain LOW. The NPN gives you true open-drain behavior.

4. HALT LED — Blue LED on /HALT

 +5V ── R6 (470Ω) ── [Blue LED] ── /HALT (pin 17)

 - /HALT HIGH (normal): no current, LED off ✓
 - /HALT LOW (CPU double-bus-fault halt, or during reset): ~3.8mA → LED on ✓
 - Blue LED Vf ≈
  3.2V → I = (5 - 3.2) / 470 ≈ 3.8mA (visible but not blinding)

 Note: The LED will also briefly illuminate during reset (both lines go low). This is expected and informative — you can add a gate to suppress it during reset if needed, but it complicates the circuit.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Bill of Materials

┌────────┬─────────────┬──────────────────────┬────────────────────────┐
│ Ref    │ Part        │ Value / Part#        │ Notes                  │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ R1, R2 │ Resistor    │ 4.7kΩ                │ /RESET, /HALT pull-ups │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ R3     │ Resistor    │ 10kΩ                 │ Switch pull-up         │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ R4     │ Resistor    │ 1kΩ                  │ Q1 base resistor       │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ R5     │ Resistor    │ 470Ω                 │ LED current limit      │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ C1     │ Capacitor   │ 1µF                  │ Debounce               │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ C2     │ Capacitor   │ 100nF                │ Bypass on U1 VCC       │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ U1     │ 74HC14      │ Hex Schmitt inverter │ Uses 2 of 6 gates      │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ U2     │ DS1813-5    │ SOT-23 supervisor    │ Or MCP130T-450         │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ Q1     │ 2N3904      │ NPN transistor       │ Any small-signal NPN   │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ SW1    │ Push button │ SPST-NO, momentary   │ Panel mount            │
├────────┼─────────────┼──────────────────────┼────────────────────────┤
│ LED1   │ Blue LED    │ 3mm or 5mm           │ Vf ~3.2V               │
└────────┴─────────────┴──────────────────────┴────────────────────────┘

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Critical Notes

 1. Both /RESET and /HALT must go LOW together for a valid MC68000 reset — never reset with /RESET alone, the CPU won't initialize properly
 2. 100ms minimum at power-on — the DS1813's 150ms pulse covers this with margin
 3. After reset releases, the CPU fetches initial SSP from $000000 and PC from $000004 — ensure ROM is mapped there