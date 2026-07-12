MC68000 /HALT & /RESET Circuit Summary

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Signal Properties

Both /RESET (pin 18) and /HALT (pin 17) are bidirectional open-drain, active-LOW. The CPU can assert them, and so can external circuitry. Both must be pulled LOW together for a valid reset.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Complete Circuit

                     R1 4.7kΩ                    
 +5V ────────────────┤├──────────────────────────── /RESET (pin 18) ──┐
                     R2 4.7kΩ                                          │
 +5V ────────────────┤├──────────────────────────── /HALT  (pin 17) ──┤
                                                                       │
          ┌── DS1813-5 (power-on reset, open-drain) ───────────────── RESET BUS
          │                                                            │
          └── U2A 74HC07 (open-drain) ───────────────────────────────┘
                   ↑
              U1A 74HC14 (Schmitt debounce)
                   ↑
          R4 10kΩ──┬──SW1──GND
                   └──C2 1µF──GND
 
 +5V ── R6 470Ω ── [Blue LED] ── /HALT (pin 17)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Three Functional Blocks

1 — Pull-ups

┌──────┬───────┬──────────────────┐
│ Part │ Value │ Function         │
├──────┼───────┼──────────────────┤
│ R1   │ 4.7kΩ │ /RESET idle HIGH │
├──────┼───────┼──────────────────┤
│ R2   │ 4.7kΩ │ /HALT idle HIGH  │
└──────┴───────┴──────────────────┘

Required because both pins are open-drain with nothing else driving them HIGH.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

2 — Power-On Reset (DS1813-5)

 - Monitors the +5V rail; asserts open-drain output LOW on power-up and on brownout
 - 150ms reset pulse — satisfies MC68000's ≥100ms requirement
 - Output wired to both /RESET and /HALT simultaneously
 - No interaction with other circuit blocks — open-drain is inherently safe to wire-OR

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

3 — Manual Reset Switch (Debounced)

┌──────────────────┬──────────────────┬─────────────────────────────────────────────────────────────┐
│ Stage            │ Parts            │ Role                                                        │
├──────────────────┼──────────────────┼─────────────────────────────────────────────────────────────┤
│ RC filter        │ R4 10kΩ + C2 1µF │ τ = 10ms, smooths contact bounce                            │
├──────────────────┼──────────────────┼─────────────────────────────────────────────────────────────┤
│ Schmitt trigger  │ U1A 74HC14       │ Converts slow RC edge to clean digital transition           │
├──────────────────┼──────────────────┼─────────────────────────────────────────────────────────────┤
│ Open-drain drive │ U2A 74HC07       │ Pulls RESET BUS LOW when switch pressed; Hi-Z when released │
└──────────────────┴──────────────────┴─────────────────────────────────────────────────────────────┘

 - SW1 pressed → U1A output HIGH → U2A pulls RESET BUS LOW → both /RESET and /HALT assert ✓  
 - SW1 released → U1A output LOW → U2A Hi-Z → pull-ups restore both lines HIGH ✓  
 - CPU asserting /RESET itself → U2A is Hi-Z, no bus contention ✓

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

4 — HALT LED Indicator

 +5V ── R6 470Ω ── [Blue LED] ── /HALT

 - /HALT HIGH (normal run): LED off
 - /HALT LOW (CPU double-bus-fault halt): LED on — ~3.8mA  
 - /HALT LOW (during reset): LED briefly on — expected, indicates reset activity

Blue LED forward voltage ~3.2V → I = (5.0 − 3.2) / 470 ≈ 3.8mA

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Bill of Materials

┌────────┬─────────────┬─────────────────────────────────────┐
│ Ref    │ Part        │ Value                               │
├────────┼─────────────┼─────────────────────────────────────┤
│ R1, R2 │ Resistor    │ 4.7kΩ                               │
├────────┼─────────────┼─────────────────────────────────────┤
│ R4     │ Resistor    │ 10kΩ                                │
├────────┼─────────────┼─────────────────────────────────────┤
│ R6     │ Resistor    │ 470Ω                                │
├────────┼─────────────┼─────────────────────────────────────┤
│ C2     │ Capacitor   │ 1µF                                 │
├────────┼─────────────┼─────────────────────────────────────┤
│ U1     │ 74HC14      │ Hex Schmitt inverter (1 gate used)  │
├────────┼─────────────┼─────────────────────────────────────┤
│ U2     │ 74HC07      │ Hex open-drain buffer (1 gate used) │
├────────┼─────────────┼─────────────────────────────────────┤
│ U3     │ DS1813-5    │ SOT-23 voltage supervisor           │
├────────┼─────────────┼─────────────────────────────────────┤
│ SW1    │ Push button │ SPST-NO momentary                   │
├────────┼─────────────┼─────────────────────────────────────┤
│ LED1   │ Blue LED    │ 3mm or 5mm, Vf ~3.2V                │
└────────┴─────────────┴─────────────────────────────────────┘

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Key Design Rules Satisfied

 - ✅ ≥100ms reset at power-on (DS1813 gives 150ms)
 - ✅ Both /RESET and /HALT asserted together on every reset
 - ✅ Open-drain throughout — safe wire-OR, no bus contention with CPU
 - ✅ Switch bounce eliminated (10ms RC + Schmitt)
 - ✅ No discrete transistors — all logic ICs
