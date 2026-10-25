/*
 * isa_risc64_boot_test.S -- test de demarrage de l'ISA RISC64 (port GAS / binutils)
 *
 * Scenario complet, au niveau assembleur :
 *   1. Reset en mode S, MMU eteinte : pile, mise a zero de .bss, canari de pile
 *   2. Configuration des traps : TBA (table alignee 32 Kio), SCRATCH, PIL, TIMECMP
 *   3. Construction des tables de pages 4 niveaux (L3 -> L2 -> L1 -> L0), pages 4 Kio,
 *      super-page 2 Mio (MMIO), giga-page 1 Gio (alias noyau haut), puis activation de PTBR
 *   4. Saut dans l'alias haut du noyau (0xffff800000000000) et tests des traps :
 *      FP desactive, instruction illegale, division par zero, point d'arret, acces non aligne,
 *      traps imbriquees (TL 1 -> 2), interruptions + PIL, pagination a la demande (bits A/D
 *      logiciels), appel systeme depuis le mode U, acces U -> page noyau, retour au noyau.
 *
 * Edition de liens attendue (pages de 4 Kio) :
 *   <cible>-ld -Ttext=0x0 -Tdata=0x20000 -Tbss=0x40000 boot.o -o boot.elf
 *
 * Resultat : l'octet R_STATUS de la structure `results` vaut 1 (PASS) ou 2 (FAIL) ;
 * la console (UART a 0x10000000) affiche BOOT puis PASS ou FAIL.
 * Fichier ASCII pur, preprocesse par cpp (#define uniquement), sans .macro.
 */

/* ---------------- constantes ---------------- */
#define UART_BASE	0x10000000
#define KBASE		0xffff800000000000
#define STACK_CANARY	0x5a5a1234a5a54321
#define DEMAND_LO	0x100000
#define DEMAND_HI	0x180000

#define PTE_V		0x001
#define PTE_R		0x002
#define PTE_W		0x004
#define PTE_X		0x008
#define PTE_U		0x010
#define PTE_G		0x020
#define PTE_A		0x040
#define PTE_D		0x080
#define PTE_TABLE	(PTE_V)
#define PTE_KRX		(PTE_V|PTE_R|PTE_X|PTE_G|PTE_A|PTE_D)
#define PTE_KRW		(PTE_V|PTE_R|PTE_W|PTE_G|PTE_A|PTE_D)
#define PTE_KRWX	(PTE_V|PTE_R|PTE_W|PTE_X|PTE_G|PTE_A|PTE_D)
#define PTE_URX		(PTE_V|PTE_R|PTE_X|PTE_U|PTE_A|PTE_D)
#define PTE_URW		(PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D)
#define PTBR_MODE4	(1<<60)
#define PTBR_ASID1	(1<<44)

#define STATUS_IE	0x1
#define STATUS_PRIV	0x2
#define STATUS_FPEN	0x4
#define STATUS_SUM	0x8
#define TSTATE_USER	(STATUS_IE|STATUS_FPEN)
#define TSTATE_SUPER	(STATUS_IE|STATUS_PRIV|STATUS_FPEN)

/* structure `results` (offsets en octets, doubles mots de 8 octets) */
#define R_SYSCALL	0
#define R_ILLEGAL	8
#define R_PRIV		16
#define R_DIV0		24
#define R_BREAK		32
#define R_MISALIGN	40
#define R_PFLOAD	48
#define R_PFSTORE	56
#define R_FPDIS		64
#define R_NEST_IN	72
#define R_NEST_OUT	80
#define R_UFAULT	88
#define R_EXIT		96
#define R_TL_SEEN	104
#define R_TT_SEEN	112
#define R_LAST_TVAL	120
#define R_IRQ_IDX	128
#define R_PHASE		136
#define R_FP		144
#define R_FAILS		152
#define R_LASTFAIL	160
#define R_STATUS	168
#define R_IRQ_LOG	176
#define R_FEATURES	208
#define R_HARTID	216

/* zone de sauvegarde des traps (pointee par le CSR SCRATCH) */
#define SA_A0		0
#define SA_A1		8
#define SA_A2		16
#define SA_A3		24
#define SA_RESULTS	32
#define SA_NEST_A0	40
#define SA_NEST_A1	48

/* ======================================================================
 *  .text : code de demarrage (execute a l'adresse physique, MMU eteinte)
 * ====================================================================== */
	.text
	.globl	_start
	.balign	4
_start:
	di				/* STATUS.IE <- 0 */
	csrw	tl, zero
	csrw	status, zero		/* FPEN = 0 : teste le trap FP desactive plus loin */
	csrw	pil, zero
	csrw	ipend, zero
	csrr	a0, hartid
	bnez	a0, park_secondary	/* seul le coeur 0 demarre */

	/* ---- 1. pile du noyau (physique) ---- */
	la	sp, kstack_top
	andi	sp, sp, -16

	/* ---- 2. mise a zero de .bss ---- */
	la	a0, bss_start
	la	a1, bss_end
bss_loop:
	bgeu	a0, a1, bss_done
	sd	zero, 0(a0)
	addi	a0, a0, 8
	j	bss_loop
bss_done:
	la	t0, kstack_bottom		/* canari au bas de la pile */
	li	t1, STACK_CANARY
	sd	t1, 0(t0)

	/* ---- 3. configuration des traps ---- */
	la	t0, trap_table
	li	t1, 0x7fff			/* TBA doit etre alignee sur 32 Kio */
	and	t1, t1, t0
	bnez	t1, boot_fail
	csrw	tba, t0
	la	t0, save_area			/* SCRATCH = &save_area (invariant du noyau) */
	csrw	scratch, t0
	la	t1, results
	sd	t1, SA_RESULTS(t0)
	li	t0, -1
	csrw	timecmp, t0			/* pas de timer pour ce test */
	csrwi	pil, 0
	csrr	t0, features
	sd	t0, R_FEATURES(t1)
	csrr	t0, hartid
	sd	t0, R_HARTID(t1)
	rdcycle	t0
	rdtime	t0
	rdinstret t0
	csrr	t0, ptbr			/* MMU eteinte au reset */
	bnez	t0, boot_fail
	csrr	t0, tl
	bnez	t0, boot_fail

	/* ---- 4. tables de pages ---- */
	/* L3[0] -> L2 bas */
	la	a0, pt_l2_low
	li	a1, PTE_TABLE
	call	make_pte
	la	t0, pt_l3
	sd	a0, 0(t0)
	/* L2bas[0] -> L1 bas */
	la	a0, pt_l1_low
	li	a1, PTE_TABLE
	call	make_pte
	la	t0, pt_l2_low
	sd	a0, 0(t0)
	/* L1bas[0] -> L0 bas (couvre 0 .. 2 Mio en pages de 4 Kio) */
	la	a0, pt_l0_low
	li	a1, PTE_TABLE
	call	make_pte
	la	t0, pt_l1_low
	sd	a0, 0(t0)
	/* L1bas[128] : super-page 2 Mio = MMIO UART a 0x10000000 */
	li	a0, UART_BASE
	li	a1, PTE_KRW
	call	make_pte
	la	t0, pt_l1_low
	sd	a0, 1024(t0)
	/* L3[256] -> L2 haut (VA 0xffff800000000000) ; 256*8 = 2048 depasse imm12 */
	la	a0, pt_l2_high
	li	a1, PTE_TABLE
	call	make_pte
	la	t0, pt_l3
	li	t1, 2048
	add	t0, t0, t1
	sd	a0, 0(t0)
	/* L2haut[0] : giga-page 1 Gio, PA 0, alias noyau R/W/X */
	li	a0, 0
	li	a1, PTE_KRWX
	call	make_pte
	la	t0, pt_l2_high
	sd	a0, 0(t0)

	/* pages 4 Kio identite : texte noyau, texte U, donnees noyau, donnees U, bss */
	li	a0, 0
	la	a1, user_text_start
	li	a2, PTE_KRX
	call	map_range
	la	a0, user_text_start
	la	a1, user_text_end
	li	a2, PTE_URX
	call	map_range
	la	a0, data_start
	la	a1, user_data_start
	li	a2, PTE_KRW
	call	map_range
	la	a0, user_data_start
	la	a1, user_data_end
	li	a2, PTE_URW
	call	map_range
	la	a0, bss_start
	la	a1, bss_end
	li	a2, PTE_KRW
	call	map_range

	/* ---- 5. activation de la pagination ---- */
	la	a0, pt_l3
	srli	a0, a0, 12			/* PPN de la racine */
	li	a1, PTBR_MODE4|PTBR_ASID1
	or	a0, a0, a1
	csrw	ptbr, a0
	tlbflush				/* invalide tout le TLB */
	fence.i
	la	t0, kmain			/* saut vers l'alias haut du noyau */
	li	t1, KBASE
	add	t0, t0, t1
	jr	t0

park_secondary:
	wfi
	j	park_secondary

boot_fail:
	li	t0, UART_BASE
	li	t1, 66				/* B */
	sb	t1, 0(t0)
	la	t2, results
	li	t0, 3
	sd	t0, R_STATUS(t2)
boot_park:
	wfi
	j	boot_park

/* make_pte(a0 = adresse physique, a1 = flags) -> a0 = PTE */
make_pte:
	srli	a0, a0, 12
	slli	a0, a0, 10
	or	a0, a0, a1
	ret

/* map_range(a0 = debut, a1 = fin, a2 = flags) : identite, dans pt_l0_low */
map_range:
	addi	sp, sp, -48
	sd	ra, 40(sp)
	sd	s0, 32(sp)
	sd	s1, 24(sp)
	sd	s2, 16(sp)
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
map_loop:
	bgeu	s0, s1, map_done
	mv	a0, s0
	mv	a1, s2
	call	make_pte
	srli	t0, s0, 12
	andi	t0, t0, 511
	slli	t0, t0, 3
	la	t1, pt_l0_low
	add	t0, t0, t1
	sd	a0, 0(t0)
	li	t1, 4096
	add	s0, s0, t1
	j	map_loop
map_done:
	ld	ra, 40(sp)
	ld	s0, 32(sp)
	ld	s1, 24(sp)
	ld	s2, 16(sp)
	addi	sp, sp, 48
	ret

/* uart_puts(a0 = chaine) */
uart_puts:
	li	t0, UART_BASE
puts_loop:
	lbu	t1, 0(a0)
	beqz	t1, puts_done
	sb	t1, 0(t0)
	addi	a0, a0, 1
	j	puts_loop
puts_done:
	ret

/* expect_eq(a0 = obtenu, a1 = attendu, a2 = numero du test) */
expect_eq:
	beq	a0, a1, expect_ok
	la	t0, results
	ld	t1, R_FAILS(t0)
	addi	t1, t1, 1
	sd	t1, R_FAILS(t0)
	sd	a2, R_LASTFAIL(t0)
expect_ok:
	ret

/* ======================================================================
 *  Table de traps : TBA + (TL>0 ? 0x4000 : 0) + TT*32  (8 instructions / entree)
 * ====================================================================== */
	.balign	32768
	.globl	trap_table
trap_table:

tt0_0x000:
	j	_start
	.balign	32
tt0_0x001:
	j	h_fatal
	.balign	32
tt0_0x002:
	j	h_fatal
	.balign	32
tt0_0x003:
	j	h_fatal
	.balign	32
tt0_0x004:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_ILLEGAL(a0)
	addi	a1, a1, 1
	sd	a1, R_ILLEGAL(a0)
	j	trap_exit_done
	.balign	32
tt0_0x005:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_PRIV(a0)
	addi	a1, a1, 1
	sd	a1, R_PRIV(a0)
	j	trap_exit_done
	.balign	32
tt0_0x006:
	j	h_fatal
	.balign	32
tt0_0x007:
	j	h_fpdis
	.balign	32
tt0_0x008:
	j	h_fatal
	.balign	32
tt0_0x009:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_DIV0(a0)
	addi	a1, a1, 1
	sd	a1, R_DIV0(a0)
	j	trap_exit_done
	.balign	32
tt0_0x00a:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_BREAK(a0)
	addi	a1, a1, 1
	sd	a1, R_BREAK(a0)
	j	trap_exit_done
	.balign	32
tt0_0x00b:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_MISALIGN(a0)
	addi	a1, a1, 1
	sd	a1, R_MISALIGN(a0)
	j	trap_exit_done
	.balign	32
tt0_0x00c:
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_MISALIGN(a0)
	addi	a1, a1, 1
	sd	a1, R_MISALIGN(a0)
	j	trap_exit_done
	.balign	32
tt0_0x00d:
	j	h_fatal
	.balign	32
tt0_0x00e:
	j	h_fatal
	.balign	32
tt0_0x00f:
	j	h_pagefault
	.balign	32
tt0_0x010:
	j	h_pagefault
	.balign	32
	.zero	1536			/* TT 0x011..0x040 : non definis (mot nul = ILLEGAL) */
tt0_0x041:
	j	h_irq
	.balign	32
tt0_0x042:
	j	h_irq
	.balign	32
tt0_0x043:
	j	h_irq
	.balign	32
tt0_0x044:
	j	h_irq
	.balign	32
tt0_0x045:
	j	h_irq
	.balign	32
tt0_0x046:
	j	h_irq
	.balign	32
tt0_0x047:
	j	h_irq
	.balign	32
tt0_0x048:
	j	h_irq
	.balign	32
tt0_0x049:
	j	h_irq
	.balign	32
tt0_0x04a:
	j	h_irq
	.balign	32
tt0_0x04b:
	j	h_irq
	.balign	32
tt0_0x04c:
	j	h_irq
	.balign	32
tt0_0x04d:
	j	h_irq
	.balign	32
tt0_0x04e:
	j	h_irq
	.balign	32
tt0_0x04f:
	j	h_irq
	.balign	32
	.zero	5632			/* TT 0x050..0x0ff : non definis (mot nul = ILLEGAL) */
tt0_0x100:
	j	h_syscall
	.balign	32
tt0_0x101:
	j	h_exit
	.balign	32
	.zero	160			/* TT 0x102..0x106 : non definis (mot nul = ILLEGAL) */
tt0_0x107:
	j	h_trap7
	.balign	32
	.balign	16384			/* debut de la moitie TL > 0 */
tt1_0x000:
	j	h_fatal
	.balign	32
tt1_0x001:
	j	h_fatal
	.balign	32
tt1_0x002:
	j	h_fatal
	.balign	32
tt1_0x003:
	j	h_fatal
	.balign	32
tt1_0x004:
	j	h_fatal
	.balign	32
tt1_0x005:
	j	h_fatal
	.balign	32
tt1_0x006:
	j	h_fatal
	.balign	32
tt1_0x007:
	j	h_fatal
	.balign	32
tt1_0x008:
	j	h_fatal
	.balign	32
tt1_0x009:
	j	h_fatal
	.balign	32
tt1_0x00a:
	j	h_fatal
	.balign	32
tt1_0x00b:
	j	h_fatal
	.balign	32
tt1_0x00c:
	j	h_fatal
	.balign	32
tt1_0x00d:
	j	h_fatal
	.balign	32
tt1_0x00e:
	j	h_fatal
	.balign	32
tt1_0x00f:
	j	h_fatal
	.balign	32
tt1_0x010:
	j	h_fatal
	.balign	32
	.zero	7904			/* TT 0x011..0x107 : non definis (mot nul = ILLEGAL) */
tt1_0x108:
	j	h_nested_sw
	.balign	32
	.balign	32768

/* ======================================================================
 *  Handlers (une seule zone de sauvegarde ; SCRATCH = &save_area, echange avec t6)
 * ====================================================================== */
trap_exit_done:
	ld	a0, SA_A0(t6)
	ld	a1, SA_A1(t6)
	csrrw	t6, scratch, t6
	done				/* PC <- TPC + 4 */
trap_exit_retry:
	ld	a0, SA_A0(t6)
	ld	a1, SA_A1(t6)
	csrrw	t6, scratch, t6
	retry				/* PC <- TPC */

h_fatal:				/* trap inattendue : on note TT / TVAL et on s'arrete */
	csrr	t0, tt
	csrr	t1, tval
	la	t2, results
	sd	t0, R_TT_SEEN(t2)
	sd	t1, R_LAST_TVAL(t2)
	li	t0, 2
	sd	t0, R_STATUS(t2)
	li	t0, UART_BASE
	li	t1, 70				/* F */
	sb	t1, 0(t0)
fatal_park:
	wfi
	j	fatal_park

h_fpdis:				/* TT 0x007 : active FPEN dans STATUS restaure par RETRY */
	csrsi	tstate, STATUS_FPEN
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_FPDIS(a0)
	addi	a1, a1, 1
	sd	a1, R_FPDIS(a0)
	j	trap_exit_retry

h_syscall:				/* TRAP 0 : a0 <- a0 + 1 */
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a1, SA_RESULTS(t6)
	ld	a0, R_SYSCALL(a1)
	addi	a0, a0, 1
	sd	a0, R_SYSCALL(a1)
	ld	a0, SA_A0(t6)
	addi	a0, a0, 1
	sd	a0, SA_A0(t6)			/* valeur de retour restauree dans a0 */
	j	trap_exit_done

h_exit:					/* TRAP 1 : fin du processus utilisateur */
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	ld	a0, SA_RESULTS(t6)
	li	a1, 1
	sd	a1, R_EXIT(a0)
kill_user:				/* retour au noyau : TPC <- kernel_resume, mode S */
	la	a0, kernel_resume
	csrw	tpc, a0
	li	a0, TSTATE_SUPER
	csrw	tstate, a0
	j	trap_exit_retry

h_trap7:				/* TRAP 7 : declenche une trap imbriquee (TL 1 -> 2) */
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	trap	8				/* t6 = &save_area : utilisable tel quel */
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_NEST_OUT(a0)
	addi	a1, a1, 1
	sd	a1, R_NEST_OUT(a0)
	j	trap_exit_done

h_nested_sw:				/* TT 0x108 a TL = 2 (moitie haute de la table) */
	sd	a0, SA_NEST_A0(t6)
	sd	a1, SA_NEST_A1(t6)
	ld	a0, SA_RESULTS(t6)
	ld	a1, R_NEST_IN(a0)
	addi	a1, a1, 1
	sd	a1, R_NEST_IN(a0)
	csrr	a1, tl				/* attendu : 2 */
	sd	a1, R_TL_SEEN(a0)
	csrr	a1, tt				/* attendu : 0x108 */
	sd	a1, R_TT_SEEN(a0)
	ld	a0, SA_NEST_A0(t6)
	ld	a1, SA_NEST_A1(t6)
	done

h_irq:					/* TT 0x041..0x04F : interruption de niveau TT - 0x40 */
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	sd	a2, SA_A2(t6)
	ld	a2, SA_RESULTS(t6)
	csrr	a0, tt
	ld	a1, R_IRQ_IDX(a2)
	slli	a1, a1, 3
	add	a1, a1, a2
	sd	a0, R_IRQ_LOG(a1)		/* journal des TT recus */
	ld	a1, R_IRQ_IDX(a2)
	addi	a1, a1, 1
	sd	a1, R_IRQ_IDX(a2)
	addi	a0, a0, -64			/* niveau */
	li	a1, 1
	sll	a1, a1, a0
	csrc	ipend, a1			/* acquittement */
	ld	a2, SA_A2(t6)
	j	trap_exit_retry

h_pagefault:				/* TT 0x00F (lecture) / 0x010 (ecriture) */
	csrrw	t6, scratch, t6
	sd	a0, SA_A0(t6)
	sd	a1, SA_A1(t6)
	sd	a2, SA_A2(t6)
	sd	a3, SA_A3(t6)
	ld	a3, SA_RESULTS(t6)
	csrr	a0, tval			/* adresse virtuelle fautive */
	sd	a0, R_LAST_TVAL(a3)
	csrr	a1, tt
	addi	a1, a1, -16			/* 0 si ecriture */
	beqz	a1, pf_cnt_store
	ld	a1, R_PFLOAD(a3)
	addi	a1, a1, 1
	sd	a1, R_PFLOAD(a3)
	j	pf_counted
pf_cnt_store:
	ld	a1, R_PFSTORE(a3)
	addi	a1, a1, 1
	sd	a1, R_PFSTORE(a3)
pf_counted:
	csrr	a1, tstate
	andi	a1, a1, STATUS_PRIV
	beqz	a1, pf_from_user		/* defaut venant du mode U */
	li	a1, DEMAND_LO			/* noyau : pagination a la demande */
	bltu	a0, a1, pf_fatal
	li	a1, DEMAND_HI
	bgeu	a0, a1, pf_fatal
	srli	a1, a0, 12
	andi	a1, a1, 511
	slli	a1, a1, 3
	la	a2, pt_l0_low
	add	a2, a2, a1			/* a2 = &PTE */
	ld	a1, 0(a2)
	bnez	a1, pf_update
	srli	a1, a0, 12			/* pas de PTE : identite V|R|W, A = D = 0 */
	slli	a1, a1, 10
	ori	a1, a1, PTE_V|PTE_R|PTE_W
	j	pf_store_pte
pf_update:				/* PTE presente : le logiciel pose A (lecture) ou A|D (ecriture) */
	ori	a1, a1, PTE_A
	csrr	a3, tt
	addi	a3, a3, -16
	bnez	a3, pf_store_pte
	ori	a1, a1, PTE_D
pf_store_pte:
	sd	a1, 0(a2)
	tlbflush a0, zero			/* invalide cette adresse, tous ASID */
	ld	a2, SA_A2(t6)
	ld	a3, SA_A3(t6)
	j	trap_exit_retry
pf_from_user:
	ld	a1, R_UFAULT(a3)
	addi	a1, a1, 1
	sd	a1, R_UFAULT(a3)
	j	kill_user
pf_fatal:
	j	h_fatal

/* ======================================================================
 *  Noyau (execute a l'alias haut 0xffff800000000000)
 * ====================================================================== */
	.balign	16
kmain:
	la	sp, kstack_top			/* pc-relatif : adresses de l'alias haut */
	la	t0, trap_table
	csrw	tba, t0				/* TBA <- alias haut */
	la	t0, kstack_bottom
	ld	t1, 0(t0)
	li	t2, STACK_CANARY
	bne	t1, t2, kmain_fail		/* canari intact ? */
	auipc	t0, 0
	srli	t0, t0, 47
	li	t1, 0x1ffff
	bne	t0, t1, kmain_fail		/* PC dans la moitie haute ? */
	la	s0, results
	j	kmain_go
kmain_fail:				/* relais : bne ne porte que sur +-8 Kio */
	j	boot_fail
kmain_go:
	la	a0, msg_boot
	call	uart_puts
	ei

	/* ---- T1 : FP desactive -> TT 0x007, handler, RETRY ---- */
	li	a0, 0x4008000000000000		/* 3.0 */
	fmv.d.x	fa0, a0				/* 1re instruction FP : trap puis re-execution */
	fli.d	fa1, 2.0
	fmul.d	fa2, fa0, fa1
	fcvt.l.d a0, fa2, rtz
	sd	a0, R_FP(s0)
	ld	a0, R_FPDIS(s0)
	li	a1, 1
	li	a2, 1
	call	expect_eq
	ld	a0, R_FP(s0)
	li	a1, 6
	li	a2, 2
	call	expect_eq

	/* ---- T2 : traps synchrones en mode S, retour par DONE ---- */
	.word	0				/* instruction illegale */
	.word	0xffffffff			/* opcode inexistant */
	li	a1, 7
	div	a0, a1, zero
	divu	a0, a1, zero
	rem	a0, a1, zero
	remuw	a0, a1, zero
	break
	ld	a0, 1(sp)			/* chargement non aligne */
	sd	a0, 3(sp)			/* rangement non aligne */
	ld	a0, R_ILLEGAL(s0)
	li	a1, 2
	li	a2, 3
	call	expect_eq
	ld	a0, R_DIV0(s0)
	li	a1, 4
	li	a2, 4
	call	expect_eq
	ld	a0, R_BREAK(s0)
	li	a1, 1
	li	a2, 5
	call	expect_eq
	ld	a0, R_MISALIGN(s0)
	li	a1, 2
	li	a2, 6
	call	expect_eq

	/* ---- T3 : traps imbriquees TL 0 -> 1 -> 2 ---- */
	trap	7
	ld	a0, R_NEST_IN(s0)
	li	a1, 1
	li	a2, 7
	call	expect_eq
	ld	a0, R_NEST_OUT(s0)
	li	a1, 1
	li	a2, 8
	call	expect_eq
	ld	a0, R_TL_SEEN(s0)
	li	a1, 2
	li	a2, 9
	call	expect_eq
	ld	a0, R_TT_SEEN(s0)
	li	a1, 0x108
	li	a2, 10
	call	expect_eq

	/* ---- T4 : interruptions et PIL ---- */
	csrwi	pil, 5				/* seuls les niveaux > 5 sont acceptes */
	li	a0, 0x60			/* niveaux 5 et 6 */
	csrs	ipend, a0			/* 6 est pris, 5 reste en attente */
	csrr	s1, ipend
	csrw	pil, zero			/* 5 devient acceptable */
	csrr	s2, ipend
	ld	a0, R_IRQ_IDX(s0)
	li	a1, 2
	li	a2, 11
	call	expect_eq
	ld	a0, R_IRQ_LOG(s0)
	li	a1, 0x46
	li	a2, 12
	call	expect_eq
	ld	a0, R_IRQ_LOG+8(s0)
	li	a1, 0x45
	li	a2, 13
	call	expect_eq
	mv	a0, s1
	li	a1, 0x20
	li	a2, 14
	call	expect_eq
	mv	a0, s2
	li	a1, 0
	li	a2, 15
	call	expect_eq

	/* ---- T5 : pagination a la demande, bits A/D geres par logiciel ---- */
	li	t0, 0x100000
	ld	a0, 0(t0)			/* defaut 1 : PTE absente ; defaut 2 : A = 0 */
	li	t1, 0x101000
	li	a0, 0x5a5a
	sd	a0, 0(t1)			/* defaut 1 : PTE absente ; defaut 2 : A = 0 */
	ld	s1, 0(t1)			/* plus de defaut */
	li	t2, 0x102000
	ld	a0, 0(t2)			/* deux defauts de lecture */
	sd	a0, 8(t2)			/* un defaut d'ecriture : D = 0 */
	ld	a0, R_PFLOAD(s0)
	li	a1, 4
	li	a2, 16
	call	expect_eq
	ld	a0, R_PFSTORE(s0)
	li	a1, 3
	li	a2, 17
	call	expect_eq
	ld	a0, R_LAST_TVAL(s0)
	li	a1, 0x102008
	li	a2, 18
	call	expect_eq
	mv	a0, s1
	li	a1, 0x5a5a
	li	a2, 19
	call	expect_eq

	/* ---- T6 : mode utilisateur, appel systeme, privilege, acces interdit ---- */
	la	a0, user_entry
	j	run_user

run_user:				/* a0 = entree utilisateur (VA basse) ; ne revient pas */
	li	t0, KBASE
	sub	a0, a0, t0
	csrwi	tl, 1
	csrw	tpc, a0
	csrwi	tstate, TSTATE_USER		/* mode U, IE = 1, FPEN = 1 */
	la	sp, user_stack_top
	sub	sp, sp, t0
	retry

kernel_resume:				/* point de retour de kill_user ; sp utilisateur perdu */
	la	sp, kstack_top
	la	s0, results
	ld	t0, R_PHASE(s0)
	addi	t0, t0, 1
	sd	t0, R_PHASE(s0)
	li	t1, 1
	beq	t0, t1, check_user1
	li	t1, 2
	beq	t0, t1, check_user2
	j	h_fatal

check_user1:
	ld	a0, R_SYSCALL(s0)
	li	a1, 1
	li	a2, 20
	call	expect_eq
	ld	a0, R_EXIT(s0)
	li	a1, 1
	li	a2, 21
	call	expect_eq
	ld	a0, R_PRIV(s0)			/* wfi + csrr status en mode U */
	li	a1, 2
	li	a2, 22
	call	expect_eq
	la	t0, user_result			/* relecture par la VA basse (page U) avec SUM = 1 */
	li	t1, KBASE
	sub	t0, t0, t1
	csrsi	status, STATUS_SUM
	ld	a0, 0(t0)
	ld	s1, 8(t0)
	csrci	status, STATUS_SUM
	li	a1, 42
	li	a2, 23
	call	expect_eq
	mv	a0, s1
	li	a1, 6
	li	a2, 24
	call	expect_eq
	csrr	a0, tl
	li	a1, 0
	li	a2, 25
	call	expect_eq
	la	a0, user_entry_fault
	j	run_user

check_user2:
	ld	a0, R_UFAULT(s0)
	li	a1, 1
	li	a2, 26
	call	expect_eq
	ld	a0, R_EXIT(s0)
	li	a1, 1
	li	a2, 27
	call	expect_eq
	la	a1, kernel_probe
	li	t1, KBASE
	sub	a1, a1, t1
	ld	a0, R_LAST_TVAL(s0)
	li	a2, 28
	call	expect_eq
	ld	a0, R_FAILS(s0)
	bnez	a0, test_failed
	la	a0, msg_pass
	call	uart_puts
	li	t0, 1
	sd	t0, R_STATUS(s0)
	j	final_park
test_failed:
	la	a0, msg_fail
	call	uart_puts
	li	t0, 2
	sd	t0, R_STATUS(s0)
final_park:
	wfi
	j	final_park

/* ======================================================================
 *  Code utilisateur : page(s) 4 Kio dediee(s), mappee(s) U + R + X
 * ====================================================================== */
	.balign	4096
user_text_start:
user_entry:
	li	a0, 41
	trap	0				/* appel systeme : a0 <- a0 + 1 */
	la	a1, user_result
	sd	a0, 0(a1)			/* 42 */
	wfi					/* privilegiee : TT 0x005, ignoree par DONE */
	csrr	a2, status			/* idem */
	li	a0, 3
	fcvt.d.l fa0, a0
	fli.d	fa1, 2.0
	fmul.d	fa0, fa0, fa1
	fcvt.l.d a0, fa0, rtz
	sd	a0, 8(a1)			/* 6 */
	trap	1				/* exit */
user_hang:
	j	user_hang
user_entry_fault:
	la	a2, kernel_probe		/* page noyau (U = 0) */
	ld	a0, 0(a2)			/* page fault -> processus tue */
	trap	1
	j	user_hang
	.balign	4096
user_text_end:

/* ======================================================================
 *  .data : donnees noyau, tables de pages, donnees utilisateur
 * ====================================================================== */
	.data
	.balign	4096
data_start:
results:
	.zero	256
save_area:
	.zero	64
kernel_probe:
	.dword	0x1122334455667788
msg_boot:
	.asciz	"BOOT\n"
msg_pass:
	.asciz	"PASS\n"
msg_fail:
	.asciz	"FAIL\n"
	.balign	4096
pt_l3:
	.zero	4096
pt_l2_low:
	.zero	4096
pt_l1_low:
	.zero	4096
pt_l0_low:
	.zero	4096
pt_l2_high:
	.zero	4096
	.balign	4096
user_data_start:
user_result:
	.zero	16
	.balign	16
user_stack_bottom:
	.zero	1024
user_stack_top:
	.balign	4096
user_data_end:

/* ======================================================================
 *  .bss : pile du noyau (8 Kio)
 * ====================================================================== */
	.bss
	.balign	4096
bss_start:
kstack_bottom:
	.zero	8192
kstack_top:
	.balign	4096
bss_end:

