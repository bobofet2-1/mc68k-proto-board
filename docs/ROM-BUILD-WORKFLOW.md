# MC68000 ROM Build and Programming Workflow

## Purpose

This workflow builds a boot ROM for the MC68000 v5 board using EASy68K,
converts the assembled S-record into a raw image with EASyBIN, and produces
one programming image for each installed 28C256 EEPROM.

Use this document with the current v5 schematic:
`hardware\MC68000-v5\MC68000.kicad_sch`.

## ROM hardware layout

The board has two 32 KiB x 8 28C256 EEPROMs that form one 64 KiB, 16-bit
logical ROM image.

| Device | Data bus | MC68000 byte addresses | Logical image bytes |
|---|---|---|---|
| U16 | `D15-D8` (high byte) | Even addresses | `0, 2, 4, ...` |
| U15 | `D7-D0` (low byte) | Odd addresses | `1, 3, 5, ...` |

The permanent ROM window begins at `0xFF0000`. Although the reset overlay
makes the first eight ROM bytes available temporarily at `0x000000-0x000007`,
the ROM image itself is laid out as if it begins at `0xFF0000`.

```text
Logical ROM offset       CPU address         Contents
------------------       -----------         --------
0x0000-0x0003            0xFF0000-0xFF0003   Initial supervisor stack pointer
0x0004-0x0007            0xFF0004-0xFF0007   Initial program counter
0x0008 onward            0xFF0008 onward     Reset handler and firmware
```

The initial program counter must point to permanent high ROM, for example
`0x00FF0008`, not to the temporary low-address overlay.

The two EEPROM images must each be exactly **32 KiB (32,768 bytes)**. The
combined logical image must be exactly **64 KiB (65,536 bytes)**. Unused
locations should contain `0xFF`.

## Directory and file convention

Create a firmware working directory outside the hardware design directory.
The following names are examples:

```text
firmware\
  src\
    boot.asm
  build\
    boot.s68
    boot.bin
    U16-high-even.bin
    U15-low-odd.bin
```

Do not program the `.S68` file into an EEPROM. It is an ASCII Motorola
S-record file, not a byte-for-byte ROM image.

## 1. Write the assembly source

Use Motorola 68000 syntax in Edit68K. Place the vector table and reset code
at their permanent ROM addresses:

```asm
        ORG     $FF0000

        DC.L    INITIAL_SSP
        DC.L    RESET_ENTRY

RESET_ENTRY:
        ; Early board bring-up code starts here.
```

Set `INITIAL_SSP` to an aligned address in installed RAM. Set `RESET_ENTRY`
to the permanent address of the first instruction, normally `0x00FF0008`.

For the first board tests, keep the reset handler small and deterministic:

1. Disable interrupts or establish the intended interrupt mask.
2. Perform the software write that clears the ROM overlay.
3. Test RAM.
4. Initialize the DUART and emit a simple diagnostic message.

Do not use EASy68K simulator-only services, especially `TRAP #15`, in code
that must run on the physical board.

`firmware\src\d2_flash.asm` is an earlier visible test that requires neither
RAM nor a serial terminal. It has hardware prerequisites documented in
`hardware\MC68000-v5\IO-DTACK-BRINGUP.md`.

## 2. Assemble with EASy68K

1. Open the source in Edit68K.
2. Assemble it successfully with no unresolved symbols or assembly errors.
3. Save the assembler output as `build\boot.s68`.
4. Run the program in Sim68K for instruction-level checks before programming
   hardware.

Verify in the S-record listing that the first data record starts at
`0xFF0000`, and that the first eight bytes encode the intended initial stack
pointer and initial program counter in big-endian order.

## 3. Convert the S-record to a logical raw binary image

Use EASyBIN to convert `build\boot.s68` to `build\boot.bin`.

When choosing the conversion range, create a flat image corresponding to the
ROM window:

```text
Start address: 0xFF0000
End address:   0xFFFFFF
Output size:   65,536 bytes
Fill value:    0xFF
```

The first byte in `boot.bin` must therefore be the byte stored at CPU address
`0xFF0000`; it is not a file offset of `0xFF0000`. Do **not** produce a file
with 16 MiB of padding before the ROM data.

If EASyBIN does not pad the selected range automatically, create/pad the
logical image before splitting it. The split step below rejects a file whose
size is not exactly 65,536 bytes.

## 4. Split the 16-bit logical image into EEPROM images

Run the following from the repository root in PowerShell:

```powershell
$logicalPath = "firmware\build\boot.bin"
$u16Path = "firmware\build\U16-high-even.bin"
$u15Path = "firmware\build\U15-low-odd.bin"

[byte[]] $logical = [System.IO.File]::ReadAllBytes($logicalPath)

if ($logical.Length -ne 65536) {
    throw "Expected a 65,536-byte logical ROM image; found $($logical.Length) bytes."
}

[byte[]] $u16 = New-Object byte[] 32768
[byte[]] $u15 = New-Object byte[] 32768

for ($i = 0; $i -lt 32768; $i++) {
    $u16[$i] = $logical[2 * $i]       # Even CPU address: D15-D8, U16
    $u15[$i] = $logical[2 * $i + 1]   # Odd CPU address: D7-D0, U15
}

[System.IO.File]::WriteAllBytes($u16Path, $u16)
[System.IO.File]::WriteAllBytes($u15Path, $u15)

Get-Item $logicalPath, $u16Path, $u15Path | Select-Object Name, Length
Get-FileHash $logicalPath, $u16Path, $u15Path -Algorithm SHA256
```

The required result is:

| File | Size | Program into |
|---|---:|---|
| `boot.bin` | 65,536 bytes | Do not program directly; input to split |
| `U16-high-even.bin` | 32,768 bytes | U16, high-byte EEPROM |
| `U15-low-odd.bin` | 32,768 bytes | U15, low-byte EEPROM |

This is an **even/odd byte de-interleave**, not a byte swap. In particular,
the first byte of the initial stack pointer goes to U16 offset `0x0000`, and
the second byte goes to U15 offset `0x0000`.

## 5. Verify the images before programming

Before inserting either device in the board, check:

1. `boot.bin` is 65,536 bytes; each chip image is 32,768 bytes.
2. Both chip images were generated from the same `boot.bin` in the same build.
3. The first eight logical bytes decode to the expected two longwords:
   initial SSP followed by initial PC.
4. The initial PC is in the permanent high-ROM window (`0xFFxxxx`).
5. Unused EEPROM bytes are `0xFF`, not implicit zero fill.
6. `U16-high-even.bin` is assigned to U16 and `U15-low-odd.bin` to U15.

To reconstruct and inspect the first eight logical bytes from the split files:

```powershell
[byte[]] $u16 = [System.IO.File]::ReadAllBytes("firmware\build\U16-high-even.bin")
[byte[]] $u15 = [System.IO.File]::ReadAllBytes("firmware\build\U15-low-odd.bin")

$firstEight = for ($i = 0; $i -lt 4; $i++) {
    $u16[$i]
    $u15[$i]
}

"First 8 logical ROM bytes: " + (($firstEight | ForEach-Object { $_.ToString("X2") }) -join " ")
```

For example, an initial PC of `0x00FF0008` appears in logical byte positions
4-7 as:

```text
00 FF 00 08
```

## 6. Program and verify the EEPROMs

Program each device as a **28C256 / 32 KiB x 8 parallel EEPROM**:

| Socket/device | Input file |
|---|---|
| U16, high-byte ROM | `U16-high-even.bin` |
| U15, low-byte ROM | `U15-low-odd.bin` |

For each EEPROM:

1. Select the exact device type supported by the programmer.
2. Load the specified 32 KiB input file at device offset `0x0000`.
3. Erase or blank-check the part if the programmer/device requires it.
4. Program the device.
5. Run the programmer's full verify operation.
6. Save or record the programmed-file SHA-256 from the split step.
7. Label the device with its reference designator, build identifier, and
   short hash.

> **Programmer details to add:** burner model, software version, device
> selection name, adapter requirements, and any proven erase/program/verify
> settings. Do not assume a programming voltage or adapter from this document.

## 7. Board insertion and first boot

With power off:

1. Install `U16-high-even.bin` in U16 and `U15-low-odd.bin` in U15.
2. Check device orientation and that the labels have not been swapped.
3. Power the board with a reset method and logic analyzer available.
4. Confirm the processor reads vectors at `0x000000`, `0x000002`,
   `0x000004`, and `0x000006`.
5. Confirm the first instruction fetch occurs from the permanent high-ROM
   address encoded in the initial PC.
6. Confirm firmware clears the overlay before using low RAM.

If the CPU fetches illegal instructions immediately after reset, first verify
that U15 and U16 were not swapped and that the logical image was split by
even/odd byte position rather than written identically to both EEPROMs.

## Rebuild rule

Every source change requires a complete repeat of the build, conversion,
split, and verify steps. Never mix U15 and U16 images from different builds.
