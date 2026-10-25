/*
 * isa_risc64_test.S -- test d'assemblage de l'ISA RISC64 (port GAS / binutils)
 *
 * Couvre chaque instruction et chaque pseudo-instruction de isa_risc64_encodage.csv,
 * avec des cas limites (imm12 = -2048 / 2047, shamt = 0 / 63, registres zero / t6 / s11,
 * modes d'arrondi, suffixes .aq/.rl, fence, constantes FLI, li 64 bits).
 *
 * Aucune dependance : uniquement des commentaires de style C, pas de macro, pas de relocation
 * explicite. Se preprocesse avec cpp (extension .S) ou s'assemble directement.
 *
 *   <cible>-gcc -c isa_risc64_test.S -o test.o
 *   <cible>-objdump -d test.o            (comparer a isa_risc64_test.expected.txt)
 *
 * Les adresses attendues supposent apres edition de liens : .text a 0x0 et .data a 0x10000
 *   <cible>-ld -Ttext=0x0 -Tdata=0x10000 test.o -o test.elf
 * Dans le .o brut, les instructions la / call (AUIPC+ADDI / AUIPC+JALR) portent des relocations.
 *
 * Legende des motifs binaires du CSV : d=rd a=rs1 b=rs2 c=rs3 m=rm i=immediate s=shamt
 *   k=csr u=uimm5 P=pred Q=succ q=aq l=rl ; 0/1 = bits fixes.
 */

	.text
	.globl	_start
_start:

/* ===== Arithmetique/Logique ===== */
	add         a0, a1, a2
	add         t6, s11, s10
	add         zero, sp, ra
	sub         a0, a1, a2
	sub         t6, s11, s10
	sub         zero, sp, ra
	and         a0, a1, a2
	and         t6, s11, s10
	and         zero, sp, ra
	or          a0, a1, a2
	or          t6, s11, s10
	or          zero, sp, ra
	xor         a0, a1, a2
	xor         t6, s11, s10
	xor         zero, sp, ra
	sll         a0, a1, a2
	sll         t6, s11, s10
	sll         zero, sp, ra
	srl         a0, a1, a2
	srl         t6, s11, s10
	srl         zero, sp, ra
	sra         a0, a1, a2
	sra         t6, s11, s10
	sra         zero, sp, ra
	slt         a0, a1, a2
	slt         t6, s11, s10
	slt         zero, sp, ra
	sltu        a0, a1, a2
	sltu        t6, s11, s10
	sltu        zero, sp, ra
	addi        a0, a1, 0
	addi        t6, s11, 2047
	addi        zero, sp, -2048
	slti        a0, a1, 0
	slti        t6, s11, 2047
	slti        zero, sp, -2048
	sltiu       a0, a1, 0
	sltiu       t6, s11, 2047
	sltiu       zero, sp, -2048
	xori        a0, a1, 0
	xori        t6, s11, 2047
	xori        zero, sp, -2048
	ori         a0, a1, 0
	ori         t6, s11, 2047
	ori         zero, sp, -2048
	andi        a0, a1, 0
	andi        t6, s11, 2047
	andi        zero, sp, -2048
	slli        a0, a1, 1
	slli        t6, s11, 63
	slli        zero, sp, 0
	srli        a0, a1, 1
	srli        t6, s11, 63
	srli        zero, sp, 0
	srai        a0, a1, 1
	srai        t6, s11, 63
	srai        zero, sp, 0
	addw        a0, a1, a2
	addw        t6, s11, s10
	addw        zero, sp, ra
	subw        a0, a1, a2
	subw        t6, s11, s10
	subw        zero, sp, ra
	sllw        a0, a1, a2
	sllw        t6, s11, s10
	sllw        zero, sp, ra
	srlw        a0, a1, a2
	srlw        t6, s11, s10
	srlw        zero, sp, ra
	sraw        a0, a1, a2
	sraw        t6, s11, s10
	sraw        zero, sp, ra
	addiw       a0, a1, 0
	addiw       t6, s11, 2047
	addiw       zero, sp, -2048
	slliw       a0, a1, 1
	slliw       t6, s11, 31
	slliw       zero, sp, 0
	srliw       a0, a1, 1
	srliw       t6, s11, 31
	srliw       zero, sp, 0
	sraiw       a0, a1, 1
	sraiw       t6, s11, 31
	sraiw       zero, sp, 0
	lui         a0, 0x12345
	lui         t6, 0xfffff
	lui         zero, 0
	auipc       a0, 0x12345
	auipc       t6, 0xfffff
	auipc       zero, 0
	czero.eqz   a0, a1, a2
	czero.eqz   t6, s11, s10
	czero.eqz   zero, sp, ra
	czero.nez   a0, a1, a2
	czero.nez   t6, s11, s10
	czero.nez   zero, sp, ra
	andn        a0, a1, a2
	andn        t6, s11, s10
	andn        zero, sp, ra
	orn         a0, a1, a2
	orn         t6, s11, s10
	orn         zero, sp, ra
	xnor        a0, a1, a2
	xnor        t6, s11, s10
	xnor        zero, sp, ra
	min         a0, a1, a2
	min         t6, s11, s10
	min         zero, sp, ra
	minu        a0, a1, a2
	minu        t6, s11, s10
	minu        zero, sp, ra
	max         a0, a1, a2
	max         t6, s11, s10
	max         zero, sp, ra
	maxu        a0, a1, a2
	maxu        t6, s11, s10
	maxu        zero, sp, ra

/* ===== Multiplication/Division ===== */
	mul         a0, a1, a2
	mul         t6, s11, s10
	mul         zero, sp, ra
	mulh        a0, a1, a2
	mulh        t6, s11, s10
	mulh        zero, sp, ra
	mulhsu      a0, a1, a2
	mulhsu      t6, s11, s10
	mulhsu      zero, sp, ra
	mulhu       a0, a1, a2
	mulhu       t6, s11, s10
	mulhu       zero, sp, ra
	div         a0, a1, a2
	div         t6, s11, s10
	div         zero, sp, ra
	divu        a0, a1, a2
	divu        t6, s11, s10
	divu        zero, sp, ra
	rem         a0, a1, a2
	rem         t6, s11, s10
	rem         zero, sp, ra
	remu        a0, a1, a2
	remu        t6, s11, s10
	remu        zero, sp, ra
	mulw        a0, a1, a2
	mulw        t6, s11, s10
	mulw        zero, sp, ra
	divw        a0, a1, a2
	divw        t6, s11, s10
	divw        zero, sp, ra
	divuw       a0, a1, a2
	divuw       t6, s11, s10
	divuw       zero, sp, ra
	remw        a0, a1, a2
	remw        t6, s11, s10
	remw        zero, sp, ra
	remuw       a0, a1, a2
	remuw       t6, s11, s10
	remuw       zero, sp, ra

/* ===== Manipulation de bits ===== */
	clz         a0, a1
	clz         t6, s11
	clz         zero, sp
	ctz         a0, a1
	ctz         t6, s11
	ctz         zero, sp
	cpop        a0, a1
	cpop        t6, s11
	cpop        zero, sp
	sext.b      a0, a1
	sext.b      t6, s11
	sext.b      zero, sp
	sext.h      a0, a1
	sext.h      t6, s11
	sext.h      zero, sp
	zext.h      a0, a1
	zext.h      t6, s11
	zext.h      zero, sp
	rev8        a0, a1
	rev8        t6, s11
	rev8        zero, sp
	rol         a0, a1, a2
	rol         t6, s11, s10
	rol         zero, sp, ra
	ror         a0, a1, a2
	ror         t6, s11, s10
	ror         zero, sp, ra
	rori        a0, a1, 1
	rori        t6, s11, 63
	rori        zero, sp, 0
	bset        a0, a1, a2
	bset        t6, s11, s10
	bset        zero, sp, ra
	bclr        a0, a1, a2
	bclr        t6, s11, s10
	bclr        zero, sp, ra
	binv        a0, a1, a2
	binv        t6, s11, s10
	binv        zero, sp, ra
	bext        a0, a1, a2
	bext        t6, s11, s10
	bext        zero, sp, ra
	bseti       a0, a1, 1
	bseti       t6, s11, 63
	bseti       zero, sp, 0
	bclri       a0, a1, 1
	bclri       t6, s11, 63
	bclri       zero, sp, 0
	binvi       a0, a1, 1
	binvi       t6, s11, 63
	binvi       zero, sp, 0
	bexti       a0, a1, 1
	bexti       t6, s11, 63
	bexti       zero, sp, 0

/* ===== Chargement/Rangement ===== */
	lb          a0, 0(a1)
	lb          t6, 2047(s11)
	lb          zero, -2048(sp)
	lh          a0, 0(a1)
	lh          t6, 2047(s11)
	lh          zero, -2048(sp)
	lw          a0, 0(a1)
	lw          t6, 2047(s11)
	lw          zero, -2048(sp)
	ld          a0, 0(a1)
	ld          t6, 2047(s11)
	ld          zero, -2048(sp)
	lbu         a0, 0(a1)
	lbu         t6, 2047(s11)
	lbu         zero, -2048(sp)
	lhu         a0, 0(a1)
	lhu         t6, 2047(s11)
	lhu         zero, -2048(sp)
	lwu         a0, 0(a1)
	lwu         t6, 2047(s11)
	lwu         zero, -2048(sp)
	sb          a2, 0(a1)
	sb          s10, 2047(s11)
	sb          ra, -2048(sp)
	sh          a2, 0(a1)
	sh          s10, 2047(s11)
	sh          ra, -2048(sp)
	sw          a2, 0(a1)
	sw          s10, 2047(s11)
	sw          ra, -2048(sp)
	sd          a2, 0(a1)
	sd          s10, 2047(s11)
	sd          ra, -2048(sp)
	prefetch    0(a1)
	prefetch    2047(s11)
	prefetch    -2048(sp)
	cbo.flush   (a1)
	cbo.flush   (s11)
	cbo.flush   (sp)
	cbo.zero    (a1)
	cbo.zero    (s11)
	cbo.zero    (sp)

/* ===== Atomique/Memoire ===== */
	lr.w        a0, (a1)
	lr.w        t6, (s11)
	lr.w        zero, (sp)
	sc.w        a0, a2, (a1)
	sc.w        t6, s10, (s11)
	sc.w        zero, ra, (sp)
	cas.w       a0, a2, (a1)
	cas.w       t6, s10, (s11)
	cas.w       zero, ra, (sp)
	amoswap.w   a0, a2, (a1)
	amoswap.w   t6, s10, (s11)
	amoswap.w   zero, ra, (sp)
	amoadd.w    a0, a2, (a1)
	amoadd.w    t6, s10, (s11)
	amoadd.w    zero, ra, (sp)
	amoxor.w    a0, a2, (a1)
	amoxor.w    t6, s10, (s11)
	amoxor.w    zero, ra, (sp)
	amoand.w    a0, a2, (a1)
	amoand.w    t6, s10, (s11)
	amoand.w    zero, ra, (sp)
	amoor.w     a0, a2, (a1)
	amoor.w     t6, s10, (s11)
	amoor.w     zero, ra, (sp)
	amomin.w    a0, a2, (a1)
	amomin.w    t6, s10, (s11)
	amomin.w    zero, ra, (sp)
	amomax.w    a0, a2, (a1)
	amomax.w    t6, s10, (s11)
	amomax.w    zero, ra, (sp)
	amominu.w   a0, a2, (a1)
	amominu.w   t6, s10, (s11)
	amominu.w   zero, ra, (sp)
	amomaxu.w   a0, a2, (a1)
	amomaxu.w   t6, s10, (s11)
	amomaxu.w   zero, ra, (sp)
	lr.d        a0, (a1)
	lr.d        t6, (s11)
	lr.d        zero, (sp)
	sc.d        a0, a2, (a1)
	sc.d        t6, s10, (s11)
	sc.d        zero, ra, (sp)
	cas.d       a0, a2, (a1)
	cas.d       t6, s10, (s11)
	cas.d       zero, ra, (sp)
	amoswap.d   a0, a2, (a1)
	amoswap.d   t6, s10, (s11)
	amoswap.d   zero, ra, (sp)
	amoadd.d    a0, a2, (a1)
	amoadd.d    t6, s10, (s11)
	amoadd.d    zero, ra, (sp)
	amoxor.d    a0, a2, (a1)
	amoxor.d    t6, s10, (s11)
	amoxor.d    zero, ra, (sp)
	amoand.d    a0, a2, (a1)
	amoand.d    t6, s10, (s11)
	amoand.d    zero, ra, (sp)
	amoor.d     a0, a2, (a1)
	amoor.d     t6, s10, (s11)
	amoor.d     zero, ra, (sp)
	amomin.d    a0, a2, (a1)
	amomin.d    t6, s10, (s11)
	amomin.d    zero, ra, (sp)
	amomax.d    a0, a2, (a1)
	amomax.d    t6, s10, (s11)
	amomax.d    zero, ra, (sp)
	amominu.d   a0, a2, (a1)
	amominu.d   t6, s10, (s11)
	amominu.d   zero, ra, (sp)
	amomaxu.d   a0, a2, (a1)
	amomaxu.d   t6, s10, (s11)
	amomaxu.d   zero, ra, (sp)

/* ===== Flottant ===== */
	fadd.s      fa0, fa1, fa2
	fadd.s      ft11, fs11, fs10, rtz
	fadd.s      f0, f1, f2, rdn
	fsub.s      fa0, fa1, fa2
	fsub.s      ft11, fs11, fs10, rtz
	fsub.s      f0, f1, f2, rdn
	fmul.s      fa0, fa1, fa2
	fmul.s      ft11, fs11, fs10, rtz
	fmul.s      f0, f1, f2, rdn
	fdiv.s      fa0, fa1, fa2
	fdiv.s      ft11, fs11, fs10, rtz
	fdiv.s      f0, f1, f2, rdn
	fsqrt.s     fa0, fa1
	fsqrt.s     ft11, fs11, rtz
	fsqrt.s     f0, f1, rdn
	fsgnj.s     fa0, fa1, fa2
	fsgnj.s     ft11, fs11, fs10
	fsgnj.s     f0, f1, f2
	fsgnjn.s    fa0, fa1, fa2
	fsgnjn.s    ft11, fs11, fs10
	fsgnjn.s    f0, f1, f2
	fsgnjx.s    fa0, fa1, fa2
	fsgnjx.s    ft11, fs11, fs10
	fsgnjx.s    f0, f1, f2
	fmin.s      fa0, fa1, fa2
	fmin.s      ft11, fs11, fs10
	fmin.s      f0, f1, f2
	fmax.s      fa0, fa1, fa2
	fmax.s      ft11, fs11, fs10
	fmax.s      f0, f1, f2
	fround.s    fa0, fa1
	fround.s    ft11, fs11, rtz
	fround.s    f0, f1, rdn
	fli.s       fa0, 1.0
	fli.s       ft11, -1.0
	fli.s       f0, inf
	fadd.d      fa0, fa1, fa2
	fadd.d      ft11, fs11, fs10, rtz
	fadd.d      f0, f1, f2, rdn
	fsub.d      fa0, fa1, fa2
	fsub.d      ft11, fs11, fs10, rtz
	fsub.d      f0, f1, f2, rdn
	fmul.d      fa0, fa1, fa2
	fmul.d      ft11, fs11, fs10, rtz
	fmul.d      f0, f1, f2, rdn
	fdiv.d      fa0, fa1, fa2
	fdiv.d      ft11, fs11, fs10, rtz
	fdiv.d      f0, f1, f2, rdn
	fsqrt.d     fa0, fa1
	fsqrt.d     ft11, fs11, rtz
	fsqrt.d     f0, f1, rdn
	fsgnj.d     fa0, fa1, fa2
	fsgnj.d     ft11, fs11, fs10
	fsgnj.d     f0, f1, f2
	fsgnjn.d    fa0, fa1, fa2
	fsgnjn.d    ft11, fs11, fs10
	fsgnjn.d    f0, f1, f2
	fsgnjx.d    fa0, fa1, fa2
	fsgnjx.d    ft11, fs11, fs10
	fsgnjx.d    f0, f1, f2
	fmin.d      fa0, fa1, fa2
	fmin.d      ft11, fs11, fs10
	fmin.d      f0, f1, f2
	fmax.d      fa0, fa1, fa2
	fmax.d      ft11, fs11, fs10
	fmax.d      f0, f1, f2
	fround.d    fa0, fa1
	fround.d    ft11, fs11, rtz
	fround.d    f0, f1, rdn
	fli.d       fa0, 1.0
	fli.d       ft11, -1.0
	fli.d       f0, inf
	fmadd.s     fa0, fa1, fa2, fa3
	fmadd.s     ft11, fs11, fs10, fs9, rtz
	fmadd.s     f0, f1, f2, f3, rdn
	fmadd.d     fa0, fa1, fa2, fa3
	fmadd.d     ft11, fs11, fs10, fs9, rtz
	fmadd.d     f0, f1, f2, f3, rdn
	fmsub.s     fa0, fa1, fa2, fa3
	fmsub.s     ft11, fs11, fs10, fs9, rtz
	fmsub.s     f0, f1, f2, f3, rdn
	fmsub.d     fa0, fa1, fa2, fa3
	fmsub.d     ft11, fs11, fs10, fs9, rtz
	fmsub.d     f0, f1, f2, f3, rdn
	fnmsub.s    fa0, fa1, fa2, fa3
	fnmsub.s    ft11, fs11, fs10, fs9, rtz
	fnmsub.s    f0, f1, f2, f3, rdn
	fnmsub.d    fa0, fa1, fa2, fa3
	fnmsub.d    ft11, fs11, fs10, fs9, rtz
	fnmsub.d    f0, f1, f2, f3, rdn
	fnmadd.s    fa0, fa1, fa2, fa3
	fnmadd.s    ft11, fs11, fs10, fs9, rtz
	fnmadd.s    f0, f1, f2, f3, rdn
	fnmadd.d    fa0, fa1, fa2, fa3
	fnmadd.d    ft11, fs11, fs10, fs9, rtz
	fnmadd.d    f0, f1, f2, f3, rdn

/* ===== Flottant - conversion ===== */
	fcvt.w.s    a0, fa1
	fcvt.w.s    t6, fs11, rtz
	fcvt.w.s    zero, f1, rdn
	fcvt.s.w    fa0, a1
	fcvt.s.w    ft11, s11, rtz
	fcvt.s.w    f0, sp, rdn
	fcvt.wu.s   a0, fa1
	fcvt.wu.s   t6, fs11, rtz
	fcvt.wu.s   zero, f1, rdn
	fcvt.s.wu   fa0, a1
	fcvt.s.wu   ft11, s11, rtz
	fcvt.s.wu   f0, sp, rdn
	fcvt.l.s    a0, fa1
	fcvt.l.s    t6, fs11, rtz
	fcvt.l.s    zero, f1, rdn
	fcvt.s.l    fa0, a1
	fcvt.s.l    ft11, s11, rtz
	fcvt.s.l    f0, sp, rdn
	fcvt.lu.s   a0, fa1
	fcvt.lu.s   t6, fs11, rtz
	fcvt.lu.s   zero, f1, rdn
	fcvt.s.lu   fa0, a1
	fcvt.s.lu   ft11, s11, rtz
	fcvt.s.lu   f0, sp, rdn
	fcvt.w.d    a0, fa1
	fcvt.w.d    t6, fs11, rtz
	fcvt.w.d    zero, f1, rdn
	fcvt.d.w    fa0, a1
	fcvt.d.w    ft11, s11
	fcvt.d.w    f0, sp
	fcvt.wu.d   a0, fa1
	fcvt.wu.d   t6, fs11, rtz
	fcvt.wu.d   zero, f1, rdn
	fcvt.d.wu   fa0, a1
	fcvt.d.wu   ft11, s11
	fcvt.d.wu   f0, sp
	fcvt.l.d    a0, fa1
	fcvt.l.d    t6, fs11, rtz
	fcvt.l.d    zero, f1, rdn
	fcvt.d.l    fa0, a1
	fcvt.d.l    ft11, s11, rtz
	fcvt.d.l    f0, sp, rdn
	fcvt.lu.d   a0, fa1
	fcvt.lu.d   t6, fs11, rtz
	fcvt.lu.d   zero, f1, rdn
	fcvt.d.lu   fa0, a1
	fcvt.d.lu   ft11, s11, rtz
	fcvt.d.lu   f0, sp, rdn
	fcvt.s.d    fa0, fa1
	fcvt.s.d    ft11, fs11, rtz
	fcvt.s.d    f0, f1, rdn
	fcvt.d.s    fa0, fa1
	fcvt.d.s    ft11, fs11
	fcvt.d.s    f0, f1
	fmv.x.w     a0, fa1
	fmv.x.w     t6, fs11
	fmv.x.w     zero, f1
	fmv.w.x     fa0, a1
	fmv.w.x     ft11, s11
	fmv.w.x     f0, sp
	fmv.x.d     a0, fa1
	fmv.x.d     t6, fs11
	fmv.x.d     zero, f1
	fmv.d.x     fa0, a1
	fmv.d.x     ft11, s11
	fmv.d.x     f0, sp

/* ===== Flottant - comparaison ===== */
	feq.s       a0, fa1, fa2
	feq.s       t6, fs11, fs10
	feq.s       zero, f1, f2
	flt.s       a0, fa1, fa2
	flt.s       t6, fs11, fs10
	flt.s       zero, f1, f2
	fle.s       a0, fa1, fa2
	fle.s       t6, fs11, fs10
	fle.s       zero, f1, f2
	fclass.s    a0, fa1
	fclass.s    t6, fs11
	fclass.s    zero, f1
	feq.d       a0, fa1, fa2
	feq.d       t6, fs11, fs10
	feq.d       zero, f1, f2
	flt.d       a0, fa1, fa2
	flt.d       t6, fs11, fs10
	flt.d       zero, f1, f2
	fle.d       a0, fa1, fa2
	fle.d       t6, fs11, fs10
	fle.d       zero, f1, f2
	fclass.d    a0, fa1
	fclass.d    t6, fs11
	fclass.d    zero, f1

/* ===== Flottant - memoire ===== */
	flw         fa0, 0(a1)
	flw         ft11, 2047(s11)
	flw         f0, -2048(sp)
	fld         fa0, 0(a1)
	fld         ft11, 2047(s11)
	fld         f0, -2048(sp)
	fsw         fa2, 0(a1)
	fsw         fs10, 2047(s11)
	fsw         f2, -2048(sp)
	fsd         fa2, 0(a1)
	fsd         fs10, 2047(s11)
	fsd         f2, -2048(sp)

/* ===== Systeme/Trap ===== */
	break
	break
	break
	retry
	retry
	retry
	done
	done
	done
	wfi
	wfi
	wfi
	csrrw       a0, fcsr, a1
	csrrw       t6, 0x100, s11
	csrrw       zero, tba, sp
	csrrs       a0, fcsr, a1
	csrrs       t6, 0x100, s11
	csrrs       zero, tba, sp
	csrrc       a0, fcsr, a1
	csrrc       t6, 0x100, s11
	csrrc       zero, tba, sp
	csrrwi      a0, fcsr, 0
	csrrwi      t6, 0x100, 31
	csrrwi      zero, tba, 10
	csrrsi      a0, fcsr, 0
	csrrsi      t6, 0x100, 31
	csrrsi      zero, tba, 10
	csrrci      a0, fcsr, 0
	csrrci      t6, 0x100, 31
	csrrci      zero, tba, 10

/* ===== Modes d'arrondi : rne rtz rdn rup rmm dyn ===== */
	fadd.d      fa0, fa1, fa2, rne
	fcvt.w.d    a0, fa1, rne
	fmadd.s     fa0, fa1, fa2, fa3, rne
	fadd.d      fa0, fa1, fa2, rtz
	fcvt.w.d    a0, fa1, rtz
	fmadd.s     fa0, fa1, fa2, fa3, rtz
	fadd.d      fa0, fa1, fa2, rdn
	fcvt.w.d    a0, fa1, rdn
	fmadd.s     fa0, fa1, fa2, fa3, rdn
	fadd.d      fa0, fa1, fa2, rup
	fcvt.w.d    a0, fa1, rup
	fmadd.s     fa0, fa1, fa2, fa3, rup
	fadd.d      fa0, fa1, fa2, rmm
	fcvt.w.d    a0, fa1, rmm
	fmadd.s     fa0, fa1, fa2, fa3, rmm
	fadd.d      fa0, fa1, fa2, dyn
	fcvt.w.d    a0, fa1, dyn
	fmadd.s     fa0, fa1, fa2, fa3, dyn

/* ===== Suffixes .aq / .rl / .aqrl ===== */
	lr.w.aq     a0, (a1)
	lr.w.rl     a0, (a1)
	lr.w.aqrl   a0, (a1)
	lr.d.aq     a0, (a1)
	lr.d.rl     a0, (a1)
	lr.d.aqrl   a0, (a1)
	sc.w.aq     a0, a2, (a1)
	sc.w.rl     a0, a2, (a1)
	sc.w.aqrl   a0, a2, (a1)
	cas.d.aq    a0, a2, (a1)
	cas.d.rl    a0, a2, (a1)
	cas.d.aqrl  a0, a2, (a1)
	amoswap.d.aq a0, a2, (a1)
	amoswap.d.rl a0, a2, (a1)
	amoswap.d.aqrl a0, a2, (a1)
	amoadd.w.aq a0, a2, (a1)
	amoadd.w.rl a0, a2, (a1)
	amoadd.w.aqrl a0, a2, (a1)
	amomaxu.d.aq a0, a2, (a1)
	amomaxu.d.rl a0, a2, (a1)
	amomaxu.d.aqrl a0, a2, (a1)

/* ===== Constantes FLI ===== */
	fli.s       fa0, 0.0
	fli.d       fs11, 0.0
	fli.s       fa0, 1.0
	fli.d       fs11, 1.0
	fli.s       fa0, -1.0
	fli.d       fs11, -1.0
	fli.s       fa0, 0.5
	fli.d       fs11, 0.5
	fli.s       fa0, 2.0
	fli.d       fs11, 2.0
	fli.s       fa0, 0.25
	fli.d       fs11, 0.25
	fli.s       fa0, 4.0
	fli.d       fs11, 4.0
	fli.s       fa0, 0.125
	fli.d       fs11, 0.125
	fli.s       fa0, 8.0
	fli.d       fs11, 8.0
	fli.s       fa0, 16.0
	fli.d       fs11, 16.0
	fli.s       fa0, 0.0625
	fli.d       fs11, 0.0625
	fli.s       fa0, 3.0
	fli.d       fs11, 3.0
	fli.s       fa0, 1.5
	fli.d       fs11, 1.5
	fli.s       fa0, 0.75
	fli.d       fs11, 0.75
	fli.s       fa0, inf
	fli.d       fs11, inf
	fli.s       fa0, -inf
	fli.d       fs11, -inf
	fli.s       fa0, nan
	fli.d       fs11, nan

/* ===== Fence, barrieres, cache ===== */
	fence
	fence rw, rw
	fence iorw, iorw
	fence r, w
	fence w, r
	fence io, io
	fence.i
	pause

/* ===== Trap, retour de trap, systeme ===== */
	trap 0
	trap 255
	trap 128
	trap 1
	break
	illegal
	retry
	done
	wfi
	tlbflush
	tlbflush a0
	tlbflush a0, a1
	tlbflush zero, zero
	tlbflush t6, s11

/* ===== Acces CSR par nom et par numero ===== */
	csrrs       a0, fflags, zero
	csrrs       a0, frm, zero
	csrrs       a0, fcsr, zero
	csrrs       a0, cycle, zero
	csrrs       a0, time, zero
	csrrs       a0, instret, zero
	csrrs       a0, status, zero
	csrrs       a0, tl, zero
	csrrs       a0, tba, zero
	csrrs       a0, tpc, zero
	csrrs       a0, tstate, zero
	csrrs       a0, tt, zero
	csrrs       a0, tval, zero
	csrrs       a0, pil, zero
	csrrs       a0, ipend, zero
	csrrs       a0, scratch, zero
	csrrs       a0, ptbr, zero
	csrrs       a0, timecmp, zero
	csrrs       a0, features, zero
	csrrs       a0, hartid, zero
	csrrw       zero, 0x0, a1
	csrrw       zero, 0x1, a1
	csrrw       zero, 0x2, a1
	csrrw       zero, 0x100, a1
	csrrw       zero, 0x10b, a1
	csrrw       zero, 0xc00, a1
	csrrw       zero, 0xd01, a1
	csrrw       zero, 0xfff, a1

/* ===== Branchements, sauts ===== */
.Lbr_back:
	nop
	beq         a0, a1, .Lbr_fwd
	beq         t6, zero, .Lbr_back
	beq         zero, s11, .Lbr_fwd
	bne         a0, a1, .Lbr_fwd
	bne         t6, zero, .Lbr_back
	bne         zero, s11, .Lbr_fwd
	blt         a0, a1, .Lbr_fwd
	blt         t6, zero, .Lbr_back
	blt         zero, s11, .Lbr_fwd
	bge         a0, a1, .Lbr_fwd
	bge         t6, zero, .Lbr_back
	bge         zero, s11, .Lbr_fwd
	bltu        a0, a1, .Lbr_fwd
	bltu        t6, zero, .Lbr_back
	bltu        zero, s11, .Lbr_fwd
	bgeu        a0, a1, .Lbr_fwd
	bgeu        t6, zero, .Lbr_back
	bgeu        zero, s11, .Lbr_fwd
	jal ra, .Lbr_fwd
	jal zero, .Lbr_back
	jal .Lbr_fwd
	jalr ra, a0, 0
	jalr zero, t6, -2048
	jalr a1, a2, 2047
	jalr a0
	jalr a1, 8(a2)
.Lbr_fwd:
	nop

/* ===== Pseudo-instructions ===== */
	mv a0, a1
	mv t6, zero
	nop
	not a0, a1
	neg a0, a1
	seqz a0, a1
	snez a0, a1
	beqz a0, .Lbr_back
	bnez a0, .Lbr_back
	bltz a0, .Lbr_back
	bgez a0, .Lbr_back
	bgtz a0, .Lbr_back
	blez a0, .Lbr_back
	bgt a0, a1, .Lbr_back
	ble a0, a1, .Lbr_back
	bgtu a0, a1, .Lbr_back
	bleu a0, a1, .Lbr_back
	j .Lbr_back
	j .Lbr_fwd
	jr a0
	jr ra
	ret
	call func_near
	call func_far
	la a0, data_word
	la t6, func_near
	la a1, data_str
	fmv.s fa0, fa1
	fmv.d fa0, fa1
	fneg.s fa0, fa1
	fneg.d fa0, fa1
	fabs.s fa0, fa1
	fabs.d ft11, fs11
	frcsr a0
	fscsr a0
	fscsr a0, a1
	frrm a0
	fsrm a1
	fsrm a0, a1
	frflags a0
	fsflags a1
	fsflags a0, a1
	csrr a0, status
	csrw status, a0
	csrs ipend, a1
	csrc ipend, a1
	csrwi pil, 15
	csrsi status, 4
	csrci status, 4
	ei
	di
	rdcycle a0
	rdtime a1
	rdinstret a2
	rdfeatures a0
	wrptbr a0

/* ===== li : toutes les longueurs de sequence ===== */
	li          a0, 0
	li          a0, 1
	li          a0, -1
	li          a0, 2047
	li          a0, -2048
	li          a0, 2048
	li          a0, -2049
	li          a0, 0x7ff
	li          a0, 0x800
	li          a0, 0xfff
	li          a0, 0x7fffffff
	li          a0, -0x80000000
	li          a0, 0x80000000
	li          a0, 0xffffffff
	li          a0, 0x12345678
	li          a0, -0x12345678
	li          a0, 0x100000000
	li          a0, 0x123456789abcdef0
	li          a0, -0x123456789abcdef0
	li          a0, 0x7fffffffffffffff
	li          a0, -0x8000000000000000
	li          a0, 0xffffffffffffffff
	li          a0, 0x00ff00ff00ff00ff
	li          a0, 0xdeadbeefcafebabe
	li          t6, 0x12345678
	li          zero, 1

/* ===== Noms de registres : r0-r31 (canonique), x0-x31, noms ABI ===== */
	add         r0, r1, r2
	add         r3, r4, r5
	add         r6, r7, r8
	add         r9, r10, r11
	add         r12, r13, r14
	add         r15, r16, r17
	add         r18, r19, r20
	add         r21, r22, r23
	add         r24, r25, r26
	add         r27, r28, r29
	add         r30, r31, r0
	sub         x0, x1, x2
	sub         x3, x4, x5
	sub         x6, x7, x8
	sub         x9, x10, x11
	sub         x12, x13, x14
	sub         x15, x16, x17
	sub         x18, x19, x20
	sub         x21, x22, x23
	sub         x24, x25, x26
	sub         x27, x28, x29
	sub         x30, x31, x0
	xor         zero, ra, sp
	xor         gp, tp, t0
	xor         t1, t2, s0
	xor         fp, s1, a0
	xor         a1, a2, a3
	xor         a4, a5, a6
	xor         a7, s2, s3
	xor         s4, s5, s6
	xor         s7, s8, s9
	xor         s10, s11, t3
	xor         t4, t5, t6
	fadd.d      f0, f1, f2
	fadd.d      f4, f5, f6
	fadd.d      f8, f9, f10
	fadd.d      f12, f13, f14
	fadd.d      f16, f17, f18
	fadd.d      f20, f21, f22
	fadd.d      f24, f25, f26
	fadd.d      f28, f29, f30
	fmul.s      ft0, ft1, ft2
	fmul.s      ft3, ft4, ft5
	fmul.s      ft6, ft7, fs0
	fmul.s      fs1, fa0, fa1
	fmul.s      fa2, fa3, fa4
	fmul.s      fa5, fa6, fa7
	fmul.s      fs2, fs3, fs4
	fmul.s      fs5, fs6, fs7
	fmul.s      fs8, fs9, fs10
	fmul.s      fs11, ft8, ft9

/* ===== Fonctions cibles pour call / la ===== */
func_near:
	ret
	.balign	16
func_far:
	nop
	ret

/* ===== Section de donnees ===== */
	.data
	.balign	8
data_word:
	.dword	0x0123456789abcdef
	.word	1, 2, 3
	.half	0x7fff
	.byte	0x80, 0xff
data_str:
	.asciz	"ISA RISC64"
	.balign	8
	.zero	16

