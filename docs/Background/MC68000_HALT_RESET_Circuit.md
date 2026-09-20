# MC68000 /HALT & /RESET Circuit

## Overview

Both /RESET (pin 18) and /HALT (pin 17) are bidirectional open-drain, active-LOW.
A valid reset requires BOTH lines asserted LOW simultaneously for >= 100ms at power-on.
The pins must NOT be tied directly together — the CPU drives each independently
(RESET opcode drives /RESET; double-bus-fault drives /HALT), so back-feeding between
them must be prevented by using separate open-drain outputs per pin.

---

## Signal Properties

| Pin | Name    | Direction      | Type        | Active |
|-----|---------|----------------|-------------|--------|
| 17  | /HALT   | Bidirectional  | Open-drain  | LOW    |
| 18  | /RESET  | Bidirectional  | Open-drain  | LOW    |

---

## Functional Blocks

### 1 — Pull-ups
R1 (4.7kΩ): +5V to MC68000 /RESET pin 18
R2 (4.7kΩ): +5V to MC68000 /HALT  pin 17

Required because both CPU pins are open-drain with nothing else driving them HIGH.

---

### 2 — Power-On Reset: DS1813-5 (SOT-23)

Monitors the +5V rail. On power-up (and on brownout below ~4.65V), asserts
open-drain /RST output LOW for 150ms — satisfies MC68000's >= 100ms requirement.

DS1813-5 Pin Connections:
  Pin 1  GND  -> GND
  Pin 2  VCC  -> +5V
  Pin 3  /RST -> R3 (10kΩ to +5V), 74HC07 pin 1, 74HC07 pin 3

R3 (10kΩ) is required to pull the DS1813 open-drain output HIGH when not asserting,
providing a valid logic level to the 74HC07 inputs.

---

### 3 — Manual Reset Switch (Debounced)

SW1 (SPST-NO momentary) with RC debounce and Schmitt trigger:

NODE_A junction:
  R4 (10kΩ)  -> +5V          (pull-up)
  C2 (1µF)   -> GND          (debounce, tau = 10ms)
  SW1        -> GND          (other terminal)
  74HC14 pin 1 (1A input)

74HC14 Gate 1 (Schmitt inverter):
  Pin 1  (1A)  <- NODE_A
  Pin 2  (1Y)  -> 74HC07 pin 5, 74HC07 pin 9

Unused 74HC14 inputs (pins 3, 5, 9, 11) -> GND

Switch logic:
  SW1 open   -> NODE_A HIGH -> 74HC14 output LOW  -> 74HC07 gates off -> /RESET, /HALT HIGH
  SW1 closed -> NODE_A LOW  -> 74HC14 output HIGH -> 74HC07 gates on  -> /RESET, /HALT LOW

---

### 4 — Open-Drain Fan-Out: 74HC07 (DIP-14)

Four gates used. Gates 1+3 drive /RESET; gates 2+4 drive /HALT.
Pins are kept electrically isolated — neither CPU pin can back-feed into the other.

| Gate | Input Pin | Output Pin | Driven By         | Drives  |
|------|-----------|------------|-------------------|---------|
| 1    | 1         | 2          | DS1813 pin 3      | /RESET  |
| 2    | 3         | 4          | DS1813 pin 3      | /HALT   |
| 3    | 5         | 6          | 74HC14 pin 2      | /RESET  |
| 4    | 9         | 8          | 74HC14 pin 2      | /HALT   |
| 5    | 11 -> GND | 10 unused  | (tie input to GND)| unused  |
| 6    | 13 -> GND | 12 unused  | (tie input to GND)| unused  |

74HC07 Power:
  Pin 14  VCC -> +5V
  Pin 7   GND -> GND

/RESET node (MC68000 pin 18):
  R1 (4.7kΩ)   -> +5V
  74HC07 pin 2 (gate 1 output, open-drain)
  74HC07 pin 6 (gate 3 output, open-drain)

/HALT node (MC68000 pin 17):
  R2 (4.7kΩ)   -> +5V
  74HC07 pin 4 (gate 2 output, open-drain)
  74HC07 pin 8 (gate 4 output, open-drain)

---

### 5 — HALT LED Indicator (Blue)

  +5V -> R6 (470Ω) -> [Blue LED anode | cathode] -> MC68000 /HALT pin 17

Blue LED Vf ~ 3.2V  ->  I = (5.0 - 3.2) / 470 = ~3.8mA

  /HALT HIGH (normal run)            : LED OFF
  /HALT LOW  (CPU double-bus-fault)  : LED ON
  /HALT LOW  (during reset)          : LED ON briefly — expected behaviour

---

## Complete Connection Table

### DS1813-5
| Pin | Name | Connects To                                    |
|-----|------|------------------------------------------------|
| 1   | GND  | GND                                            |
| 2   | VCC  | +5V                                            |
| 3   | /RST | R3 (10kΩ to +5V), 74HC07 pin1, 74HC07 pin3    |

### 74HC14 (gate 1 only)
| Pin | Name        | Connects To                    |
|-----|-------------|--------------------------------|
| 1   | 1A (input)  | NODE_A                         |
| 2   | 1Y (output) | 74HC07 pin 5, 74HC07 pin 9     |
| 3   | 2A          | GND (unused input)             |
| 5   | 3A          | GND (unused input)             |
| 7   | GND         | GND                            |
| 9   | 4A          | GND (unused input)             |
| 11  | 5A          | GND (unused input)             |
| 14  | VCC         | +5V                            |

### 74HC07
| Pin | Name          | Connects To                          | Purpose               |
|-----|---------------|--------------------------------------|-----------------------|
| 1   | 1A (input)    | DS1813 pin 3                         | power-on reset        |
| 2   | 1Y (out, OD)  | /RESET node -> MC68000 pin 18        | drives /RESET         |
| 3   | 2A (input)    | DS1813 pin 3                         | power-on reset        |
| 4   | 2Y (out, OD)  | /HALT  node -> MC68000 pin 17        | drives /HALT          |
| 5   | 3A (input)    | 74HC14 pin 2                         | switch reset          |
| 6   | 3Y (out, OD)  | /RESET node -> MC68000 pin 18        | drives /RESET         |
| 7   | GND           | GND                                  |                       |
| 8   | 4Y (out, OD)  | /HALT  node -> MC68000 pin 17        | drives /HALT          |
| 9   | 4A (input)    | 74HC14 pin 2                         | switch reset          |
| 11  | 5A (input)    | GND                                  | tie unused input      |
| 13  | 6A (input)    | GND                                  | tie unused input      |
| 14  | VCC           | +5V                                  |                       |

### MC68000 (relevant pins)
| Pin | Name    | Connects To                                              |
|-----|---------|----------------------------------------------------------|
| 14  | VCC     | +5V                                                      |
| 16  | GND     | GND                                                      |
| 17  | /HALT   | R2 (4.7kΩ to +5V), 74HC07 pin4, pin8, LED1 cathode      |
| 18  | /RESET  | R1 (4.7kΩ to +5V), 74HC07 pin2, pin6                    |

### Debounce (NODE_A)
| Component | Value  | Connects To           |
|-----------|--------|-----------------------|
| R4        | 10kΩ   | +5V                   |
| C2        | 1µF    | GND                   |
| SW1       | SPST-NO| GND (other terminal)  |
| 74HC14 pin 1 |     | input                 |

---

## Bill of Materials

| Ref        | Part       | Value / Part#   | Notes                          |
|------------|------------|-----------------|--------------------------------|
| R1, R2     | Resistor   | 4.7kΩ           | /RESET and /HALT pull-ups      |
| R3         | Resistor   | 10kΩ            | DS1813 output pull-up          |
| R4         | Resistor   | 10kΩ            | Switch pull-up                 |
| R6         | Resistor   | 470Ω            | LED current limit              |
| C2         | Capacitor  | 1µF             | Switch debounce                |
| C3, C4, C5 | Capacitor  | 100nF ceramic   | Bypass cap, one per IC         |
| U1         | 74HC14     | DIP-14          | Hex Schmitt inverter (1 used)  |
| U2         | 74HC07     | DIP-14          | Hex open-drain buffer (4 used) |
| U3         | DS1813-5   | SOT-23          | Voltage supervisor, 150ms      |
| SW1        | Push button| SPST-NO         | Panel mount momentary          |
| LED1       | Blue LED   | 3mm or 5mm      | Vf ~3.2V                       |

---

## Behaviour Summary

| Event                      | /RESET  | /HALT   | LED | Result              |
|----------------------------|---------|---------|-----|---------------------|
| Power-on                   | LOW     | LOW     | ON  | CPU resets          |
| Brownout (<4.65V)          | LOW     | LOW     | ON  | CPU resets          |
| Manual SW1 pressed         | LOW     | LOW     | ON  | CPU resets          |
| CPU executes RESET opcode  | LOW*    | HIGH    | OFF | Peripherals reset   |
| CPU double-bus-fault halt  | HIGH    | LOW     | ON  | CPU halted, LED on  |
| Normal operation           | HIGH    | HIGH    | OFF | Running             |

* CPU drives /RESET LOW itself during RESET opcode.
  Because /RESET and /HALT are isolated (separate 74HC07 outputs),
  /HALT stays HIGH and the CPU does not halt. Correct behaviour.

---

## Design Notes

1. Never connect /RESET and /HALT directly together. The RESET opcode causes
   the CPU to drive /RESET LOW — if tied to /HALT, the CPU would halt itself
   (deadlock). The separate open-drain gate outputs per pin prevent this.

2. The DS1813-5 150ms reset pulse satisfies the MC68000 minimum 100ms requirement
   with 50ms margin.

3. After reset releases, the CPU reads initial SSP from address $000000 and
   initial PC from $000004. Ensure ROM is mapped at address 0.

4. Place 100nF ceramic bypass capacitors as close as possible to each IC's
   VCC/GND pins to suppress switching noise.

5. Unused 74HC07 and 74HC14 inputs must be tied to GND (not left floating).
