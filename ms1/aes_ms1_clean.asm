.MODEL SMALL
.STACK 100H

.DATA
state    DB 32h, 88h, 31h, 0E0h
         DB 43h, 5Ah, 31h, 37h
         DB 0F6h, 30h, 98h, 07h
         DB 0A8h, 8Dh, 0A2h, 34h

roundkey DB 16 DUP(0FFh)

col_temp DB 4 DUP(0)

sbox     DB 63h, 7Ch, 77h, 7Bh, 0F2h, 6Bh, 6Fh, 0C5h, 30h, 01h, 67h, 2Bh, 0FEh, 0D7h, 0ABh, 76h
         DB 0CAh, 82h, 0C9h, 7Dh, 0FAh, 59h, 47h, 0F0h, 0ADh, 0D4h, 0A2h, 0AFh, 9Ch, 0A4h, 72h, 0C0h
         DB 0B7h, 0FDh, 93h, 26h, 36h, 3Fh, 0F7h, 0CCh, 34h, 0A5h, 0E5h, 0F1h, 71h, 0D8h, 31h, 15h
         DB 04h, 0C7h, 23h, 0C3h, 18h, 96h, 05h, 9Ah, 07h, 12h, 80h, 0E2h, 0EBh, 27h, 0B2h, 75h
         DB 09h, 83h, 2Ch, 1Ah, 1Bh, 6Eh, 5Ah, 0A0h, 52h, 3Bh, 0D6h, 0B3h, 29h, 0E3h, 2Fh, 84h
         DB 53h, 0D1h, 00h, 0EDh, 20h, 0FCh, 0B1h, 5Bh, 6Ah, 0CBh, 0BEh, 39h, 4Ah, 4Ch, 58h, 0CFh
         DB 0D0h, 0EFh, 0AAh, 0FBh, 43h, 4Dh, 33h, 85h, 45h, 0F9h, 02h, 7Fh, 50h, 3Ch, 9Fh, 0A8h
         DB 51h, 0A3h, 40h, 8Fh, 92h, 9Dh, 38h, 0F5h, 0BCh, 0B6h, 0DAh, 21h, 10h, 0FFh, 0F3h, 0D2h
         DB 0CDh, 0Ch, 13h, 0ECh, 5Fh, 97h, 44h, 17h, 0C4h, 0A7h, 7Eh, 3Dh, 64h, 5Dh, 19h, 73h
         DB 60h, 81h, 4Fh, 0DCh, 22h, 2Ah, 90h, 88h, 46h, 0EEh, 0B8h, 14h, 0DEh, 5Eh, 0Bh, 0DBh
         DB 0E0h, 32h, 3Ah, 0Ah, 49h, 06h, 24h, 5Ch, 0C2h, 0D3h, 0ACh, 62h, 91h, 95h, 0E4h, 79h
         DB 0E7h, 0C8h, 37h, 6Dh, 8Dh, 0D5h, 4Eh, 0A9h, 6Ch, 56h, 0F4h, 0EAh, 65h, 7Ah, 0AEh, 08h
         DB 0BAh, 78h, 25h, 2Eh, 1Ch, 0A6h, 0B4h, 0C6h, 0E8h, 0DDh, 74h, 1Fh, 4Bh, 0BDh, 8Bh, 8Ah
         DB 70h, 3Eh, 0B5h, 66h, 48h, 03h, 0F6h, 0Eh, 61h, 35h, 57h, 0B9h, 86h, 0C1h, 1Dh, 9Eh
         DB 0E1h, 0F8h, 98h, 11h, 69h, 0D9h, 8Eh, 94h, 9Bh, 1Eh, 87h, 0E9h, 0CEh, 55h, 28h, 0DFh
         DB 8Ch, 0A1h, 89h, 0Dh, 0BFh, 0E6h, 42h, 68h, 41h, 99h, 2Dh, 0Fh, 0B0h, 54h, 0BBh, 16h

SubBytes MACRO
    LOCAL sb_loop
    LEA   SI, state
    MOV   CX, 16

sb_loop:
    MOV   AL, [SI]
    MOV   AH, 0
    LEA   BX, sbox
    ADD   BX, AX
    MOV   AL, [BX]
    MOV   [SI], AL
    INC   SI
    LOOP  sb_loop
ENDM

ShiftRows MACRO
    LEA   SI, state

    MOV   AL, [SI+1]
    MOV   AH, [SI+5]
    MOV   [SI+1], AH
    MOV   AH, [SI+9]
    MOV   [SI+5], AH
    MOV   AH, [SI+13]
    MOV   [SI+9], AH
    MOV   [SI+13], AL

    MOV   AL, [SI+2]
    MOV   AH, [SI+10]
    MOV   [SI+2], AH
    MOV   [SI+10], AL

    MOV   AL, [SI+6]
    MOV   AH, [SI+14]
    MOV   [SI+6], AH
    MOV   [SI+14], AL

    MOV   AL, [SI+15]
    MOV   AH, [SI+11]
    MOV   [SI+15], AH
    MOV   AH, [SI+7]
    MOV   [SI+11], AH
    MOV   AH, [SI+3]
    MOV   [SI+7], AH
    MOV   [SI+3], AL
ENDM

MixColumns MACRO
    LOCAL mc_loop
    LEA   SI, state
    MOV   CX, 4

mc_loop:
    PUSH  CX

    MOV   AL, [SI+0]
    CALL  xtime
    MOV   BL, AL

    MOV   AL, [SI+1]
    MOV   DL, AL
    CALL  xtime
    XOR   AL, DL
    XOR   BL, AL

    MOV   AL, [SI+2]
    XOR   BL, AL

    MOV   AL, [SI+3]
    XOR   BL, AL

    LEA   DI, col_temp
    MOV   [DI+0], BL

    MOV   BL, [SI+0]

    MOV   AL, [SI+1]
    CALL  xtime
    XOR   BL, AL

    MOV   AL, [SI+2]
    MOV   DL, AL
    CALL  xtime
    XOR   AL, DL
    XOR   BL, AL

    MOV   AL, [SI+3]
    XOR   BL, AL
    MOV   [DI+1], BL

    MOV   BL, [SI+0]
    MOV   AL, [SI+1]
    XOR   BL, AL

    MOV   AL, [SI+2]
    CALL  xtime
    XOR   BL, AL

    MOV   AL, [SI+3]
    MOV   DL, AL
    CALL  xtime
    XOR   AL, DL
    XOR   BL, AL
    MOV   [DI+2], BL

    MOV   AL, [SI+0]
    MOV   DL, AL
    CALL  xtime
    XOR   AL, DL
    MOV   BL, AL

    MOV   AL, [SI+1]
    XOR   BL, AL

    MOV   AL, [SI+2]
    XOR   BL, AL

    MOV   AL, [SI+3]
    CALL  xtime
    XOR   BL, AL
    MOV   [DI+3], BL

    MOV   AL, [DI+0]
    MOV   [SI+0], AL
    MOV   AL, [DI+1]
    MOV   [SI+1], AL
    MOV   AL, [DI+2]
    MOV   [SI+2], AL
    MOV   AL, [DI+3]
    MOV   [SI+3], AL

    ADD   SI, 4
    POP   CX
    LOOP  mc_loop
ENDM

AddRoundKey MACRO
    LOCAL ark_loop
    LEA   SI, state
    LEA   DI, roundkey
    MOV   CX, 16

ark_loop:
    MOV   AL, [SI]
    MOV   AH, [DI]
    XOR   AL, AH
    MOV   [SI], AL
    INC   SI
    INC   DI
    LOOP  ark_loop
ENDM

.CODE

xtime PROC
    SHL   AL, 1
    JNC   xtime_done
    XOR   AL, 1Bh
xtime_done:
    RET
xtime ENDP

MAIN PROC
    MOV   AX, @DATA
    MOV   DS, AX

    SubBytes
    ShiftRows
    MixColumns
    AddRoundKey

    MOV   AH, 4Ch
    INT   21h
MAIN ENDP

END MAIN

