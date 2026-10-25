# Every instruction below must be rejected by GAS.
 add r32, a0, a1
 addi a0, a1, 2048
 slli a0, a1, 64
 slliw a0, a1, 32
 trap 256
 csrrw a0, 4096, a1
 fadd.s fa0, fa1, fa2, reserved5
 fli.d fa0, 17.0
 add.aq a0, a1, a2
 beq a0, a1, 2
