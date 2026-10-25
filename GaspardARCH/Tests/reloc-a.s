 .text
 .globl _start
_start:
 beq a0, a1, target
 jal ra, target
 la a0, datum
 call target
 .data
 .dword datum
