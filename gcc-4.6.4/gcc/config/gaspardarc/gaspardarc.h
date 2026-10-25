/* Experimental GaspardARC LP64 ABI v0. GPL-3.0-or-later. */
#ifndef GCC_GASPARDARC_H
#define GCC_GASPARDARC_H
#define TARGET_CPU_CPP_BUILTINS() do { builtin_define("__gaspardarc__"); builtin_define("__GASPARDARC_ABI__=0"); } while(0)
#undef STARTFILE_SPEC
#define STARTFILE_SPEC ""
#undef ENDFILE_SPEC
#define ENDFILE_SPEC ""
#undef LIB_SPEC
#define LIB_SPEC ""
#undef LINK_SPEC
#define LINK_SPEC "%{shared:%eGaspardARC v0 does not support shared linking}"
#define BITS_BIG_ENDIAN 0
#define BYTES_BIG_ENDIAN 0
#define WORDS_BIG_ENDIAN 0
#define BITS_PER_WORD 64
#define UNITS_PER_WORD 8
#define POINTER_SIZE 64
#define SHORT_TYPE_SIZE 16
#define INT_TYPE_SIZE 32
#define LONG_TYPE_SIZE 64
#define LONG_LONG_TYPE_SIZE 64
#define FLOAT_TYPE_SIZE 32
#define DOUBLE_TYPE_SIZE 64
#define LONG_DOUBLE_TYPE_SIZE 64
#define DEFAULT_SIGNED_CHAR 1
#undef SIZE_TYPE
#define SIZE_TYPE "long unsigned int"
#undef PTRDIFF_TYPE
#define PTRDIFF_TYPE "long int"
#undef WCHAR_TYPE
#define WCHAR_TYPE "int"
#undef WCHAR_TYPE_SIZE
#define WCHAR_TYPE_SIZE 32
#define FUNCTION_BOUNDARY 32
#define STACK_BOUNDARY 128
#define PREFERRED_STACK_BOUNDARY 128
#define PARM_BOUNDARY 64
#define BIGGEST_ALIGNMENT 128
#define EMPTY_FIELD_BOUNDARY 32
#define STRUCTURE_SIZE_BOUNDARY 8
#define PCC_BITFIELD_TYPE_MATTERS 1
#define STRICT_ALIGNMENT 1
#define SLOW_BYTE_ACCESS 0
#define MAX_FIXED_MODE_SIZE 64
#define MOVE_MAX 8
#define Pmode DImode
#define FUNCTION_MODE QImode
#define FIRST_PSEUDO_REGISTER 34
#define REGISTER_NAMES {"zero","ra","sp","gp","tp","t0","t1","t2","s0","s1", \
 "a0","a1","a2","a3","a4","a5","a6","a7","s2","s3","s4","s5","s6","s7", \
 "s8","s9","s10","s11","t3","t4","t5","t6","?fp","?ap"}
#define FIXED_REGISTERS {1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1}
#define CALL_USED_REGISTERS {1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1}
enum reg_class {NO_REGS,GENERAL_REGS,ALL_REGS,LIM_REG_CLASSES};
#define N_REG_CLASSES LIM_REG_CLASSES
#define REG_CLASS_NAMES {"NO_REGS","GENERAL_REGS","ALL_REGS"}
#define REG_CLASS_CONTENTS {{0,0},{0xfffffffe,3},{0xffffffff,3}}
#define IRA_COVER_CLASSES {GENERAL_REGS,LIM_REG_CLASSES}
#define REGNO_REG_CLASS(R) GENERAL_REGS
#define HARD_REGNO_NREGS(R,M) ((GET_MODE_SIZE(M)+7)/8)
#define HARD_REGNO_MODE_OK(R,M) ((R)>0 && (R)<32 && (R)+HARD_REGNO_NREGS(R,M)<=32)
#define CLASS_MAX_NREGS(C,M) ((GET_MODE_SIZE(M)+7)/8)
#define MODES_TIEABLE_P(A,B) (GET_MODE_SIZE(A)<=8 && GET_MODE_SIZE(B)<=8)
#define STACK_POINTER_REGNUM 2
#define HARD_FRAME_POINTER_REGNUM 8
#define FRAME_POINTER_REGNUM 32
#define ARG_POINTER_REGNUM 33
#define STATIC_CHAIN_REGNUM 7
#define STACK_GROWS_DOWNWARD
#define FRAME_GROWS_DOWNWARD 1
#define STARTING_FRAME_OFFSET (-112)
#define FIRST_PARM_OFFSET(F) 0
#define ACCUMULATE_OUTGOING_ARGS 1
#define ELIMINABLE_REGS {{FRAME_POINTER_REGNUM,HARD_FRAME_POINTER_REGNUM},{ARG_POINTER_REGNUM,HARD_FRAME_POINTER_REGNUM}}
#define INITIAL_ELIMINATION_OFFSET(F,T,O) ((O)=0)
#define EPILOGUE_USES(R) ((R)==1)
#define INCOMING_RETURN_ADDR_RTX gen_rtx_REG(DImode,1)
#define DWARF_FRAME_RETURN_COLUMN 1
#define DWARF_REG_TO_UNWIND_COLUMN(R) (R)
#define DWARF2_DEBUGGING_INFO 1
#define CUMULATIVE_ARGS unsigned int
#define INIT_CUMULATIVE_ARGS(C,F,L,D,N) ((C)=0)
#define FUNCTION_ARG_REGNO_P(R) ((R)>=10 && (R)<=17)
#define BASE_REG_CLASS GENERAL_REGS
#define INDEX_REG_CLASS NO_REGS
#define MAX_REGS_PER_ADDRESS 1
#define REGNO_OK_FOR_BASE_P(R) gaspardarc_regno_ok_for_base((R),true)
#define REGNO_OK_FOR_INDEX_P(R) 0
#define LEGITIMATE_CONSTANT_P(X) (GET_CODE(X)!=CONST_DOUBLE)
#define TRULY_NOOP_TRUNCATION(OUT,IN) 1
#define LOAD_EXTEND_OP(MODE) SIGN_EXTEND
#define CASE_VECTOR_MODE DImode
#define DEFAULT_PCC_STRUCT_RETURN 0
#define ASM_COMMENT_START "#"
#define ASM_APP_ON "#APP\n"
#define ASM_APP_OFF "#NO_APP\n"
#define FILE_ASM_OP "\t.file\t"
#define TEXT_SECTION_ASM_OP "\t.text"
#define DATA_SECTION_ASM_OP "\t.data"
#define GLOBAL_ASM_OP "\t.globl\t"
#define ASM_OUTPUT_ALIGN(F,P) fprintf(F,"\t.p2align %d\n",P)
#define PRINT_OPERAND(F,X,C) gaspardarc_print_operand(F,X,C)
#define PRINT_OPERAND_ADDRESS(F,X) gaspardarc_print_address(F,X)
#define FUNCTION_PROFILER(F,L) error("GaspardARC profiling is not implemented")
#define CLEAR_INSN_CACHE(BEG,END) __asm__ __volatile__ ("fence.i" ::: "memory")
#define TRAMPOLINE_SIZE 16
#define TRAMPOLINE_ALIGNMENT 32
#endif
