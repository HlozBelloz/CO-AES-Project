# 8086 Implementation of 128-bit AES (Advanced Encryption Standard)

Computer Organization & System Programming (CSIS 402) project implementing the Rijndael AES-128 block cipher in 16-bit Intel 8086 assembly language.

## Project Structure

```text
├── ms1/
│   ├── aes_ms1.asm                           # Fully documented assembly source code (with comprehensive comments)
│   ├── aes_ms1_clean.asm                     # Clean assembly source code (uncommented, for submission)
│   ├── AES_Milestone1_Comprehensive_Guide.pdf # In-depth technical architecture and instruction mapping guide
│   └── AES_Milestone1_Professor_Oral_Defense.pdf # Oral defense prep with examiner questions, model answers, and rubric
├── material/                                 # Course lecture slides & reference materials
├── .gitignore
└── README.md
```

## Milestone 1 Implementation

Milestone 1 implements four core AES transformation modules as 8086 assembly macros, combining them into one full encryption round on a 128-bit state:

1. **`SubBytes()`**: Non-linear byte substitution using a 256-byte Rijndael S-Box via register indirect addressing (`[BX]`).
2. **`ShiftRows()`**: Row permutations applied to the 4×4 state matrix via circular left shifting.
3. **`MixColumns()`**: GF($2^8$) Galois Field matrix multiplication using an `xtime` polynomial reduction procedure modulo $m(x) = x^8 + x^4 + x^3 + x + 1$ (11Bh).
4. **`AddRoundKey()`**: Bitwise XOR key injection on the 128-bit state with a 16-byte `0FFh` round key.

## Tooling & Execution

The source files are structured for **MASM / TASM** running under **DOSBox** (compatible with the VS Code `MASM/TASM` extension) and can also run in **EMU8086**.
