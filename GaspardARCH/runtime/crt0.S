/* Link with board.ld; no operating-system calls. */
 .text
 .p2align 2
 .globl _start
_start:
 la sp, __stack_top
 la t0, __bss_start
 la t1, __bss_end
1:
 beq t0, t1, 2f
 sb zero, 0(t0)
 addi t0, t0, 1
 j 1b
2:
 call main
 la t0, __exit_code
 sd a0, 0(t0)
3:
 j 3b
 .section .bss,"aw",@nobits
 .p2align 3
 .globl __exit_code
__exit_code:
 .zero 8
