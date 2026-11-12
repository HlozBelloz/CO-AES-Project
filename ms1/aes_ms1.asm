; ==============================================================================
; COURSE: CSIS 402 - Computer Organization & System Programming
; PROJECT: An 8086 Implementation of 128-bit AES (Advanced Encryption Standard)
; MILESTONE 1: One Full AES Encryption Round
;              - SubBytes()  Macro  [128-bit state]
;              - ShiftRows() Macro  [128-bit state]
;              - MixColumns() Macro [128-bit state]
;              - AddRoundKey() Macro [128-bit state, Key = 16 bytes of 0FFh]
; TARGET EMULATOR: MASM / TASM (via DOSBox) or EMU8086
; ==============================================================================

.MODEL SMALL            ; Sets memory model: Code <= 64KB, Data <= 64KB
.STACK 100H             ; Allocates 256 bytes (100h) for the program stack

; ==============================================================================
; DATA SEGMENT: Holds variables, tables, and working buffers
; ==============================================================================
.DATA

    ; --------------------------------------------------------------------------
    ; 1. AES 128-BIT STATE MATRIX (16 Bytes)
    ; --------------------------------------------------------------------------
    ; AES organizes 128 bits of data as a 4x4 matrix of bytes:
    ;
    ;                Col 0    Col 1    Col 2    Col 3
    ;      Row 0:   state[0] state[4] state[8] state[12]
    ;      Row 1:   state[1] state[5] state[9] state[13]
    ;      Row 2:   state[2] state[6] state[10] state[14]
    ;      Row 3:   state[3] state[7] state[11] state[15]
    ;
    ; IMPORTANT: In memory, the state is stored COLUMN-MAJOR:
    ; Column 0 = bytes at offset 0, 1, 2, 3
    ; Column 1 = bytes at offset 4, 5, 6, 7
    ; Column 2 = bytes at offset 8, 9, 10, 11
    ; Column 3 = bytes at offset 12, 13, 14, 15
    ; Total memory footprint = 16 bytes = 128 bits.
    ; --------------------------------------------------------------------------
    state    DB 32h, 88h, 31h, 0E0h       ; Column 0 (Row 0..3)
             DB 43h, 5Ah, 31h, 37h        ; Column 1 (Row 0..3)
             DB 0F6h, 30h, 98h, 07h       ; Column 2 (Row 0..3)
             DB 0A8h, 8Dh, 0A2h, 34h      ; Column 3 (Row 0..3)

    ; --------------------------------------------------------------------------
    ; 2. ROUND KEY FOR MILESTONE 1 (128 bits = 16 Bytes)
    ; --------------------------------------------------------------------------
    ; The milestone specification specifies: Key = F F F F F F F F F F F F F F F F
    ; Represented as 16 consecutive bytes of 0FFh.
    ; --------------------------------------------------------------------------
    roundkey DB 16 DUP(0FFh)

    ; --------------------------------------------------------------------------
    ; 3. MIXCOLUMNS COLUMN TEMPORARY BUFFER (4 Bytes)
    ; --------------------------------------------------------------------------
    ; During MixColumns, all 4 output bytes of a column depend on all 4 input
    ; bytes simultaneously. If we overwrite state bytes directly in place,
    ; subsequent equations for that column would read corrupt input.
    ; Thus, new column values are written here, then copied back.
    ; --------------------------------------------------------------------------
    col_temp DB 4 DUP(0)

    ; --------------------------------------------------------------------------
    ; 4. RIJNDAEL S-BOX LOOKUP TABLE (256 Bytes)
    ; --------------------------------------------------------------------------
    ; WHY IS THIS 256 BYTES WHEN THE BLOCK IS 128 BITS?
    ; - The data block being encrypted is 128 bits (16 bytes).
    ; - However, SubBytes substitutes EACH individual 8-bit byte.
    ; - An 8-bit byte can have any value from 00h (0) to FFh (255) -> 256 possibilities.
    ; - Therefore, the substitution table requires 256 entries to map any byte.
    ; --------------------------------------------------------------------------
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


; ==============================================================================
; MACRO DEFINITIONS
; ==============================================================================

; ==============================================================================
; MACRO 1: SubBytes
; Purpose: Non-linear byte substitution using the AES S-Box table.
; Operates on: All 16 bytes (128 bits) of the state matrix.
; Addressing Mode Used: Register Indirect Addressing ([BX])
; How it works:
;   For each byte i from 0 to 15:
;     1. Read byte = state[i]
;     2. Calculate effective address: BX = offset(sbox) + byte
;     3. Read sbox[byte] from memory location [BX]
;     4. Store sbox[byte] back to state[i]
; ==============================================================================
SubBytes MACRO
    LOCAL sb_loop               ; Generates unique assembler label per macro call
    LEA   SI, state             ; SI = pointer to state array start (Source Index)
    MOV   CX, 16                ; CX = counter: 16 bytes to process in the loop

sb_loop:
    MOV   AL, [SI]              ; Load current state byte into AL
    MOV   AH, 0                 ; Zero-extend AL into AX (so AX = 00xxh)
    LEA   BX, sbox              ; BX = base address of the S-Box table
    ADD   BX, AX                ; BX = BX + AX (Base + Offset = address of sbox[AL])
    MOV   AL, [BX]              ; Register Indirect: Load substituted byte from [BX]
    MOV   [SI], AL              ; Write substituted byte back into state[SI]
    INC   SI                    ; Move pointer to the next state byte
    LOOP  sb_loop               ; Decrement CX; if CX != 0, jump to sb_loop
ENDM


; ==============================================================================
; MACRO 2: ShiftRows
; Purpose: Cyclically left-shifts rows of the 4x4 state matrix:
;          - Row 0: No shift (indices 0, 4, 8, 12 remain unchanged)
;          - Row 1: Shift left by 1 byte  (indices: 1 <- 5 <- 9 <- 13 <- 1)
;          - Row 2: Shift left by 2 bytes (swap pairs: 2 <-> 10 and 6 <-> 14)
;          - Row 3: Shift left by 3 bytes = rotate right by 1 byte
;                   (indices: 15 -> 3 -> 7 -> 11 -> 15)
; Operates on: All 16 bytes (128 bits) of the state matrix.
; Addressing Mode Used: Based Relative / Displacement ([SI + disp])
; Note: Direct byte moves avoid loop overhead and branching penalty.
; ==============================================================================
ShiftRows MACRO
    LEA   SI, state             ; SI points to base of state matrix

    ; --------------------------------------------------------------------------
    ; ROW 1: Shift Left by 1 position (Bytes at offsets 1, 5, 9, 13)
    ; New mapping: [1] <= [5],  [5] <= [9],  [9] <= [13],  [13] <= [1]
    ; --------------------------------------------------------------------------
    MOV   AL, [SI+1]            ; AL = original state[1] (save in temporary register)
    MOV   AH, [SI+5]            ; AH = state[5]
    MOV   [SI+1], AH            ; state[1] = state[5]
    MOV   AH, [SI+9]            ; AH = state[9]
    MOV   [SI+5], AH            ; state[5] = state[9]
    MOV   AH, [SI+13]           ; AH = state[13]
    MOV   [SI+9], AH            ; state[9] = state[13]
    MOV   [SI+13], AL           ; state[13] = original state[1]

    ; --------------------------------------------------------------------------
    ; ROW 2: Shift Left by 2 positions (Bytes at offsets 2, 6, 10, 14)
    ; New mapping: swap(state[2], state[10]) and swap(state[6], state[14])
    ; --------------------------------------------------------------------------
    MOV   AL, [SI+2]            ; AL = state[2]
    MOV   AH, [SI+10]           ; AH = state[10]
    MOV   [SI+2], AH            ; state[2] = state[10]
    MOV   [SI+10], AL           ; state[10] = old state[2]

    MOV   AL, [SI+6]            ; AL = state[6]
    MOV   AH, [SI+14]           ; AH = state[14]
    MOV   [SI+6], AH            ; state[6] = state[14]
    MOV   [SI+14], AL           ; state[14] = old state[6]

    ; --------------------------------------------------------------------------
    ; ROW 3: Shift Left by 3 positions = Rotate Right by 1 position
    ; (Bytes at offsets 3, 7, 11, 15)
    ; New mapping: [15] <= [11], [11] <= [7], [7] <= [3], [3] <= [15]
    ; --------------------------------------------------------------------------
    MOV   AL, [SI+15]           ; AL = original state[15] (temporary holding)
    MOV   AH, [SI+11]           ; AH = state[11]
    MOV   [SI+15], AH           ; state[15] = state[11]
    MOV   AH, [SI+7]            ; AH = state[7]
    MOV   [SI+11], AH           ; state[11] = state[7]
    MOV   AH, [SI+3]            ; AH = state[3]
    MOV   [SI+7], AH            ; state[7] = state[3]
    MOV   [SI+3], AL            ; state[3] = original state[15]
ENDM


; ==============================================================================
; MACRO 3: MixColumns
; Purpose: Multiplies each 4-byte column by the standard AES MDS matrix in GF(2^8):
;
;          | r0 |   | 02  03  01  01 |   | s0 |
;          | r1 | = | 01  02  03  01 | * | s1 |
;          | r2 |   | 01  01  02  03 |   | s2 |
;          | r3 |   | 03  01  01  02 |   | s3 |
;
; Formulas per column:
;   r0 = (2 * s0) XOR (3 * s1) XOR       s2  XOR       s3
;   r1 =       s0  XOR (2 * s1) XOR (3 * s2) XOR       s3
;   r2 =       s0  XOR       s1  XOR (2 * s2) XOR (3 * s3)
;   r3 = (3 * s0) XOR       s1  XOR       s2  XOR (2 * s3)
;
; Note on GF(2^8) arithmetic:
;   - Addition is XOR.
;   - Multiplication by 2 is performed by the xtime procedure.
;   - Multiplication by 3 is: 3*x = (2*x) XOR x = xtime(x) XOR x.
; ==============================================================================
MixColumns MACRO
    LOCAL mc_loop
    LEA   SI, state             ; SI points to start of state matrix
    MOV   CX, 4                 ; Process all 4 columns (1 column = 4 bytes)

mc_loop:
    PUSH  CX                    ; Preserve outer column loop counter on stack

    ; --------------------------------------------------------------------------
    ; COMPUTE r0 = (2*s0) XOR (3*s1) XOR s2 XOR s3
    ; --------------------------------------------------------------------------
    MOV   AL, [SI+0]            ; AL = s0
    CALL  xtime                 ; AL = 2 * s0
    MOV   BL, AL                ; BL acts as our running XOR accumulator = 2*s0

    MOV   AL, [SI+1]            ; AL = s1
    MOV   DL, AL                ; DL = s1 backup
    CALL  xtime                 ; AL = 2 * s1
    XOR   AL, DL                ; AL = (2 * s1) XOR s1 = 3 * s1
    XOR   BL, AL                ; BL = (2*s0) XOR (3*s1)

    MOV   AL, [SI+2]            ; AL = s2
    XOR   BL, AL                ; BL = ... XOR s2

    MOV   AL, [SI+3]            ; AL = s3
    XOR   BL, AL                ; BL = ... XOR s3 -> r0 is complete

    LEA   DI, col_temp          ; DI points to temporary column storage
    MOV   [DI+0], BL            ; Save r0 into col_temp[0]

    ; --------------------------------------------------------------------------
    ; COMPUTE r1 = s0 XOR (2*s1) XOR (3*s2) XOR s3
    ; --------------------------------------------------------------------------
    MOV   BL, [SI+0]            ; BL = s0

    MOV   AL, [SI+1]            ; AL = s1
    CALL  xtime                 ; AL = 2 * s1
    XOR   BL, AL                ; BL = s0 XOR (2*s1)

    MOV   AL, [SI+2]            ; AL = s2
    MOV   DL, AL                ; DL = s2 backup
    CALL  xtime                 ; AL = 2 * s2
    XOR   AL, DL                ; AL = (2*s2) XOR s2 = 3 * s2
    XOR   BL, AL                ; BL = s0 XOR (2*s1) XOR (3*s2)

    MOV   AL, [SI+3]            ; AL = s3
    XOR   BL, AL                ; BL = ... XOR s3 -> r1 is complete
    MOV   [DI+1], BL            ; Save r1 into col_temp[1]

    ; --------------------------------------------------------------------------
    ; COMPUTE r2 = s0 XOR s1 XOR (2*s2) XOR (3*s3)
    ; --------------------------------------------------------------------------
    MOV   BL, [SI+0]            ; BL = s0
    MOV   AL, [SI+1]            ; AL = s1
    XOR   BL, AL                ; BL = s0 XOR s1

    MOV   AL, [SI+2]            ; AL = s2
    CALL  xtime                 ; AL = 2 * s2
    XOR   BL, AL                ; BL = s0 XOR s1 XOR (2*s2)

    MOV   AL, [SI+3]            ; AL = s3
    MOV   DL, AL                ; DL = s3 backup
    CALL  xtime                 ; AL = 2 * s3
    XOR   AL, DL                ; AL = (2*s3) XOR s3 = 3 * s3
    XOR   BL, AL                ; BL = ... XOR (3*s3) -> r2 is complete
    MOV   [DI+2], BL            ; Save r2 into col_temp[2]

    ; --------------------------------------------------------------------------
    ; COMPUTE r3 = (3*s0) XOR s1 XOR s2 XOR (2*s3)
    ; --------------------------------------------------------------------------
    MOV   AL, [SI+0]            ; AL = s0
    MOV   DL, AL                ; DL = s0 backup
    CALL  xtime                 ; AL = 2 * s0
    XOR   AL, DL                ; AL = 3 * s0
    MOV   BL, AL                ; BL = 3 * s0

    MOV   AL, [SI+1]            ; AL = s1
    XOR   BL, AL                ; BL = (3*s0) XOR s1

    MOV   AL, [SI+2]            ; AL = s2
    XOR   BL, AL                ; BL = (3*s0) XOR s1 XOR s2

    MOV   AL, [SI+3]            ; AL = s3
    CALL  xtime                 ; AL = 2 * s3
    XOR   BL, AL                ; BL = ... XOR (2*s3) -> r3 is complete
    MOV   [DI+3], BL            ; Save r3 into col_temp[3]

    ; --------------------------------------------------------------------------
    ; WRITE COMPLETED 4 BYTES FROM col_temp BACK TO THE STATE COLUMN
    ; --------------------------------------------------------------------------
    MOV   AL, [DI+0]
    MOV   [SI+0], AL            ; state[SI+0] = r0
    MOV   AL, [DI+1]
    MOV   [SI+1], AL            ; state[SI+1] = r1
    MOV   AL, [DI+2]
    MOV   [SI+2], AL            ; state[SI+2] = r2
    MOV   AL, [DI+3]
    MOV   [SI+3], AL            ; state[SI+3] = r3

    ; Move SI pointer by 4 bytes to the next column
    ADD   SI, 4
    POP   CX                    ; Restore outer column loop counter
    LOOP  mc_loop               ; Process all 4 columns
ENDM


; ==============================================================================
; MACRO 4: AddRoundKey
; Purpose: Bitwise XORs each byte of the state with the corresponding round key byte.
; Operates on: All 16 bytes (128 bits) of the state matrix.
; Milestone 1 Key: 16 bytes of 0FFh (inverting every bit: A XOR 0FFh = NOT A).
; General design: Fully functional for ANY 128-bit round key in Milestone 2.
; ==============================================================================
AddRoundKey MACRO
    LOCAL ark_loop
    LEA   SI, state             ; SI points to state matrix base
    LEA   DI, roundkey          ; DI points to roundkey array base
    MOV   CX, 16                ; Loop counter: 16 bytes (128 bits)

ark_loop:
    MOV   AL, [SI]              ; AL = state byte
    MOV   AH, [DI]              ; AH = key byte
    XOR   AL, AH                ; AL = state[i] XOR key[i]
    MOV   [SI], AL              ; Write result back to state[i]
    INC   SI                    ; Advance state pointer to next byte
    INC   DI                    ; Advance key pointer to next byte
    LOOP  ark_loop              ; Decrement CX and repeat until all 16 bytes done
ENDM


; ==============================================================================
; CODE SEGMENT
; ==============================================================================
.CODE

; ------------------------------------------------------------------------------
; PROCEDURE: xtime
; Purpose: Multiplies a byte by 2 (polynomial multiplication by x) in GF(2^8)
;          modulo the irreducible polynomial m(x) = x^8 + x^4 + x^3 + x + 1 (11Bh).
; Input:   AL = operand byte
; Output:  AL = result of (AL * 2) in GF(2^8)
; Flags Affected: CF, OF, SF, ZF, AF, PF
; Algorithm:
;   1. Shift AL left by 1 bit (SHL AL, 1).
;      - Bit 7 moves into the Carry Flag (CF).
;      - Bits 0..6 shift left into positions 1..7, bit 0 becomes 0.
;   2. If CF == 0 (no overflow past degree 7):
;      - The multiplication result fits in 8 bits. Done!
;   3. If CF == 1 (degree 8 exceeded):
;      - We must subtract/XOR the irreducible polynomial 11Bh.
;      - Because bit 8 is already shifted out into CF, we only need to
;        XOR the remaining low 8 bits with 1Bh!
; ------------------------------------------------------------------------------
xtime PROC
    SHL   AL, 1                 ; Shift left: CF receives old bit 7
    JNC   xtime_done            ; If CF == 0, no reduction needed -> return
    XOR   AL, 1Bh               ; If CF == 1, reduce by XORing with 1Bh
xtime_done:
    RET                         ; Return to caller (pops return IP from stack)
xtime ENDP

; ------------------------------------------------------------------------------
; PROCEDURE: MAIN
; Purpose: Program entry point.
;          1. Initializes DS to point to the DATA segment.
;          2. Sequentially executes one round of AES encryption:
;             SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
;          3. Returns control cleanly to DOS.
; ------------------------------------------------------------------------------
MAIN PROC
    ; Mandatory MASM Data Segment Initialization:
    ; CS and IP are set automatically by the loader, but DS must be loaded manually.
    MOV   AX, @DATA             ; Load base address of DATA segment into AX
    MOV   DS, AX                ; Copy AX into DS (segment registers cannot be loaded directly)

    ; --------------------------------------------------------------------------
    ; ONE FULL AES-128 ENCRYPTION ROUND
    ; --------------------------------------------------------------------------
    SubBytes                    ; Round Step 1: Byte substitution via S-Box
    ShiftRows                   ; Round Step 2: Row cyclic permutation
    MixColumns                  ; Round Step 3: Column mixing in GF(2^8)
    AddRoundKey                 ; Round Step 4: XOR with Round Key (16 x 0FFh)

    ; Clean Program Termination (DOS Interrupt 21h, Function 4Ch)
    MOV   AH, 4Ch               ; Service 4Ch: Terminate process
    INT   21h                   ; DOS API interrupt
MAIN ENDP

END MAIN                        ; End of source file; marks MAIN as entry point
