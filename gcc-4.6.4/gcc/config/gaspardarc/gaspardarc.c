/* Experimental GaspardARC C backend. GPL-3.0-or-later. */
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "rtl.h"
#include "regs.h"
#include "hard-reg-set.h"
#include "insn-config.h"
#include "conditions.h"
#include "insn-flags.h"
#include "output.h"
#include "insn-attr.h"
#include "flags.h"
#include "recog.h"
#include "reload.h"
#include "diagnostic-core.h"
#include "tree.h"
#include "expr.h"
#include "optabs.h"
#include "function.h"
#include "target.h"
#include "target-def.h"
#include "tm_p.h"
#include "df.h"

bool gaspardarc_regno_ok_for_base(unsigned int r,bool strict)
{
  if(r>=FIRST_PSEUDO_REGISTER)
    { if(!strict)return true; r=reg_renumber[r]; }
  return r>0&&r<FIRST_PSEUDO_REGISTER;
}
static bool ga_address(enum machine_mode m ATTRIBUTE_UNUSED,rtx x,bool strict)
{
  if(REG_P(x))return gaspardarc_regno_ok_for_base(REGNO(x),strict);
  return GET_CODE(x)==PLUS && REG_P(XEXP(x,0)) && CONST_INT_P(XEXP(x,1))
    && gaspardarc_regno_ok_for_base(REGNO(XEXP(x,0)),strict)
    && IN_RANGE(INTVAL(XEXP(x,1)),-2048,2047);
}
void gaspardarc_print_address(FILE *f,rtx x)
{
  if(REG_P(x))fprintf(f,"0(%s)",reg_names[REGNO(x)]);
  else if(GET_CODE(x)==PLUS&&REG_P(XEXP(x,0))&&CONST_INT_P(XEXP(x,1)))
    fprintf(f,HOST_WIDE_INT_PRINT_DEC "(%s)",INTVAL(XEXP(x,1)),reg_names[REGNO(XEXP(x,0))]);
  else output_operand_lossage("invalid GaspardARC memory address");
}
void gaspardarc_print_operand(FILE *f,rtx x,int c)
{
  if(c=='z'&&x==const0_rtx){fputs("zero",f);return;}
  if(REG_P(x))fputs(reg_names[REGNO(x)],f);
  else if(MEM_P(x))gaspardarc_print_address(f,XEXP(x,0));
  else output_addr_const(f,x);
}
void gaspardarc_expand_move(rtx *o)
{
  enum machine_mode mode=GET_MODE(o[0]);
  if(MEM_P(o[0])&&!register_operand(o[1],mode))o[1]=force_reg(mode,o[1]);
}
const char *gaspardarc_output_move(rtx *o)
{
  enum machine_mode m=GET_MODE(o[0]);unsigned sz=GET_MODE_SIZE(m);
  if(REG_P(o[0])&&REG_P(o[1]))return "mv\t%0,%1";
  if(MEM_P(o[0]))return sz==8?"sd\t%1,%0":sz==4?"sw\t%1,%0":sz==2?"sh\t%1,%0":"sb\t%1,%0";
  if(MEM_P(o[1]))return sz==8?"ld\t%0,%1":sz==4?"lw\t%0,%1":sz==2?"lh\t%0,%1":"lb\t%0,%1";
  if(CONST_INT_P(o[1]))return "li\t%0,%1";
  return "la\t%0,%1";
}
static rtx ga_arg(CUMULATIVE_ARGS *c,enum machine_mode m,const_tree t ATTRIBUTE_UNUSED,bool named ATTRIBUTE_UNUSED)
{return m==VOIDmode||*c>=8?NULL_RTX:gen_rtx_REG(m,10+*c);}
static void ga_advance(CUMULATIVE_ARGS *c,enum machine_mode m ATTRIBUTE_UNUSED,const_tree t ATTRIBUTE_UNUSED,bool n ATTRIBUTE_UNUSED){++*c;}
static bool ga_byref(CUMULATIVE_ARGS *c ATTRIBUTE_UNUSED,enum machine_mode m,const_tree t,bool n ATTRIBUTE_UNUSED)
{return t?(AGGREGATE_TYPE_P(t)||int_size_in_bytes(t)<0||int_size_in_bytes(t)>8):GET_MODE_SIZE(m)>8;}
static bool ga_retmem(const_tree t,const_tree f ATTRIBUTE_UNUSED)
{return AGGREGATE_TYPE_P(t)||int_size_in_bytes(t)<0||int_size_in_bytes(t)>8;}
static rtx ga_value(const_tree t,const_tree f ATTRIBUTE_UNUSED,bool out ATTRIBUTE_UNUSED)
{return gen_rtx_REG(TYPE_MODE(t),10);}
static rtx ga_libvalue(enum machine_mode m,const_rtx f ATTRIBUTE_UNUSED){return gen_rtx_REG(m,10);}
static bool ga_value_reg(unsigned r){return r==10;}
static bool ga_frame_required(void){return true;}
static void ga_override(void)
{ if(flag_pic)error("GaspardARC v0 does not support PIC"); flag_omit_frame_pointer=0; }
static bool saved(unsigned r)
{return r==1||r==8||(!call_used_regs[r]&&df_regs_ever_live_p(r));}
static HOST_WIDE_INT frame_size(void)
{
  unsigned r;HOST_WIDE_INT n=get_frame_size()+crtl->outgoing_args_size+112;
  (void)r;
  return (n+15)&~(HOST_WIDE_INT)15;
}
/* t6 is fixed, so it is safe even after reload. It is never an ABI argument. */
static void add_sp(HOST_WIDE_INT delta)
{
  rtx x=GEN_INT(delta),insn;
  if(!IN_RANGE(delta,-2048,2047))
    {rtx tmp=gen_rtx_REG(DImode,31);emit_move_insn(tmp,x);x=tmp;}
  insn=emit_insn(gen_adddi3(stack_pointer_rtx,stack_pointer_rtx,x));
  RTX_FRAME_RELATED_P(insn)=1;
  add_reg_note(insn,REG_FRAME_RELATED_EXPR,
    gen_rtx_SET(VOIDmode,stack_pointer_rtx,plus_constant(stack_pointer_rtx,delta)));
}
static rtx slot(HOST_WIDE_INT off)
{
  rtx addr=plus_constant(hard_frame_pointer_rtx,off);
  if(!IN_RANGE(off,-2048,2047))
    {rtx t=gen_rtx_REG(DImode,31);emit_move_insn(t,GEN_INT(off));emit_insn(gen_adddi3(t,hard_frame_pointer_rtx,t));addr=t;}
  return gen_frame_mem(DImode,addr);
}
void gaspardarc_expand_prologue(void)
{
  unsigned r;HOST_WIDE_INT off=-8,sz=frame_size();rtx oldfp=gen_rtx_REG(DImode,5),insn;
  if(stdarg_p(TREE_TYPE(current_function_decl)))error("GaspardARC ABI v0: variadic functions are not supported");
  /* Preserve the caller's s0 while installing incoming SP as the frame base. */
  emit_move_insn(oldfp,hard_frame_pointer_rtx);
  insn=emit_move_insn(hard_frame_pointer_rtx,stack_pointer_rtx);RTX_FRAME_RELATED_P(insn)=1;
  add_sp(-sz);
  for(r=1;r<32;++r)if(saved(r))
    {insn=emit_move_insn(slot(off),r==8?oldfp:gen_rtx_REG(DImode,r));
     if(r!=8)RTX_FRAME_RELATED_P(insn)=1;
     off-=8;}
}
void gaspardarc_expand_epilogue(void)
{
  unsigned r;HOST_WIDE_INT off=-8;rtx oldfp=gen_rtx_REG(DImode,5);
  for(r=1;r<32;++r)if(saved(r))
    {emit_move_insn(r==8?oldfp:gen_rtx_REG(DImode,r),slot(off));off-=8;}
  emit_move_insn(stack_pointer_rtx,hard_frame_pointer_rtx);
  emit_move_insn(hard_frame_pointer_rtx,oldfp);
  emit_jump_insn(gen_ga_return());
}
static void ga_trampoline(rtx m ATTRIBUTE_UNUSED,tree f ATTRIBUTE_UNUSED,rtx c ATTRIBUTE_UNUSED)
{error("GaspardARC v0 does not support nested-function trampolines");}
#undef TARGET_OPTION_OVERRIDE
#define TARGET_OPTION_OVERRIDE ga_override
#undef TARGET_LEGITIMATE_ADDRESS_P
#define TARGET_LEGITIMATE_ADDRESS_P ga_address
#undef TARGET_FUNCTION_ARG
#define TARGET_FUNCTION_ARG ga_arg
#undef TARGET_FUNCTION_ARG_ADVANCE
#define TARGET_FUNCTION_ARG_ADVANCE ga_advance
#undef TARGET_PASS_BY_REFERENCE
#define TARGET_PASS_BY_REFERENCE ga_byref
#undef TARGET_RETURN_IN_MEMORY
#define TARGET_RETURN_IN_MEMORY ga_retmem
#undef TARGET_FUNCTION_VALUE
#define TARGET_FUNCTION_VALUE ga_value
#undef TARGET_LIBCALL_VALUE
#define TARGET_LIBCALL_VALUE ga_libvalue
#undef TARGET_FUNCTION_VALUE_REGNO_P
#define TARGET_FUNCTION_VALUE_REGNO_P ga_value_reg
#undef TARGET_FRAME_POINTER_REQUIRED
#define TARGET_FRAME_POINTER_REQUIRED ga_frame_required
#undef TARGET_TRAMPOLINE_INIT
#define TARGET_TRAMPOLINE_INIT ga_trampoline
struct gcc_target targetm=TARGET_INITIALIZER;
