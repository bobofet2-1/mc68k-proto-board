; MC68000 v5 D2 LED ROM bring-up test
;
; Build this source with EASy68K, then follow docs\ROM-BUILD-WORKFLOW.md
; to create the U16 and U15 EEPROM images.
;
; Hardware prerequisites:
;   - D2 must be connected active-low: +5V -> R18 -> D2 anode; D2 cathode
;     -> U29 Y7 (/CS_LED).
;   - /CS_LED must be included in the I/O /DTACK acknowledge logic.
;   - The current v5 decoder connects U11 Y4 to I/O and U29 inputs to
;     BA17, BA18, and BA19. This makes U29 Y3 the overlay page at $860000
;     and U29 Y7 (D2) at $8E0000.
;
; D2 is driven directly by the decoder rather than by a latch. It is on only
; while Y7 is selected, so LED_ON_WINDOW repeatedly writes the LED address
; to create a visible average current. Adjust the loop constants for the
; installed CPU clock and LED brightness.

OVL_CONTROL_PAGE    EQU     $00860000
D2_SELECT_ADDRESS   EQU     $008E0000

INITIAL_SSP         EQU     $0001FFFC

LED_ON_WINDOWS      EQU     5
LED_OFF_WINDOWS     EQU     5

                ORG     $FF0000

                DC.L    INITIAL_SSP
                DC.L    RESET_ENTRY

RESET_ENTRY:
                MOVE.W  #$2700,SR              ; Mask interrupts during bring-up.
                MOVEQ   #0,D0

                LEA     OVL_CONTROL_PAGE,A1
                MOVE.B  D0,(A1)                ; Write once to release the ROM overlay.

                LEA     D2_SELECT_ADDRESS,A0

FLASH_FOREVER:
                BSR     LED_ON_WINDOW
                BSR     LED_OFF_WINDOW
                BRA.S   FLASH_FOREVER

; Keep selecting U29 Y7. Each write asserts the active-low LED select.
LED_ON_WINDOW:
                MOVE.W  #LED_ON_WINDOWS,D2
.WINDOW:
                MOVE.W  #$FFFF,D1
.REFRESH:
                MOVE.B  D0,(A0)
                DBRA    D1,.REFRESH
                DBRA    D2,.WINDOW
                RTS

; ROM fetches continue, but no access selects U29 Y7, so D2 is off.
LED_OFF_WINDOW:
                MOVE.W  #LED_OFF_WINDOWS,D2
.WINDOW:
                MOVE.W  #$FFFF,D1
.DELAY:
                DBRA    D1,.DELAY
                DBRA    D2,.WINDOW
                RTS

                END     RESET_ENTRY
