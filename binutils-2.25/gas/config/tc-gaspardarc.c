/* GaspardARC GAS backend, ISA from supplied CSV. GPL-3.0-or-later. */
#include "as.h"
#include "safe-ctype.h"
#include "opcode/gaspardarc.h"
#include "elf/gaspardarc.h"

const char comment_chars[]="#", line_comment_chars[]="#", line_separator_chars[]=";";
const char FLT_CHARS[]="rRsSfFdDxXpP", EXP_CHARS[]="eE";
const pseudo_typeS md_pseudo_table[]={
 {"word",cons,4},{"half",cons,2},{"dword",cons,8},{0,0,0}};
const char *md_shortopts="";
struct option md_longopts[]={{NULL,0,NULL,0}};
size_t md_longopts_size=sizeof(md_longopts);
int md_parse_option(int c ATTRIBUTE_UNUSED, char *a ATTRIBUTE_UNUSED){return 0;}
void md_show_usage(FILE *f){fprintf(f,"GaspardARC ELF64 little-endian, fixed 4-byte instructions.\n");}
void md_operand(expressionS *e ATTRIBUTE_UNUSED){}
void md_begin(void){target_big_endian=0; bfd_set_arch_mach(stdoutput,TARGET_ARCH,0);}
void md_number_to_chars(char *p,valueT v,int n){number_to_chars_littleendian(p,v,n);}
char *md_atof(int type,char *lit,int *size)
{
  LITTLENUM_TYPE words[4]; char *end; int n,i;
  if(type=='f'||type=='s') n=2; else if(type=='d'||type=='r') n=4;
  else { *size=0; return "unsupported float format"; }
  end=atof_ieee(input_line_pointer,type,words); if(end)input_line_pointer=end;
  *size=n*2; for(i=n-1;i>=0;--i){md_number_to_chars(lit,words[i],2);lit+=2;} return NULL;
}
static char *trim(char *p)
{ char *e; while(ISSPACE(*p))++p; e=p+strlen(p); while(e>p&&ISSPACE(e[-1]))*--e=0; return p; }
static int regno(const char *s,int fp)
{
  int i; char *e; long n;
  if((s[0]=='r'||s[0]=='x')&&!fp)
    { n=strtol(s+1,&e,10); if(e!=s+1&&!*e&&n>=0&&n<32)return n; }
  if(s[0]=='f'&&fp)
    { n=strtol(s+1,&e,10); if(e!=s+1&&!*e&&n>=0&&n<32)return n; }
  for(i=0;i<32;++i)if(!strcmp(s,fp?ga_fpr_names[i]:ga_gpr_names[i]))return i;
  if(!fp&&!strcmp(s,"fp"))return 8;
  as_bad("invalid %s register `%s'",fp?"floating":"integer",s); return 0;
}
static expressionS ga_expr(char *s)
{
  expressionS e; char *save=input_line_pointer;
  input_line_pointer=s; expression(&e);
  while(ISSPACE(*input_line_pointer))++input_line_pointer;
  if(*input_line_pointer)as_bad("trailing characters in expression `%s'",s);
  input_line_pointer=save; return e;
}
static offsetT imm(char *s,offsetT lo,offsetT hi)
{
  expressionS e=ga_expr(s);
  if(e.X_op!=O_constant){as_bad("expected an absolute constant `%s'",s);return 0;}
  if(e.X_add_number<lo||e.X_add_number>hi)as_bad("immediate out of range `%s'",s);
  return e.X_add_number;
}
static void emit(unsigned long w)
{ char *p=frag_more(4); md_number_to_chars(p,(valueT)w,4); }
static void reloc_word(unsigned long w,expressionS *e,bfd_reloc_code_real_type code)
{
  char *p=frag_more(4); md_number_to_chars(p,(valueT)w,4);
  fix_new_exp(frag_now,p-frag_now->fr_literal,4,e,1,code);
}
static offsetT sext12(valueT v)
{ return (offsetT)((v&4095)^2048)-2048; }
static void li(unsigned rd,valueT v)
{
  offsetT lo=sext12(v); valueT hi; unsigned shift;
  if((offsetT)v>=-2048&&(offsetT)v<=2047)
    {emit(0x13|(rd<<7)|((v&4095)<<20));return;}
  if((offsetT)v>=(-2147483647-1)&&(offsetT)v<=2147483647)
    { emit(0x37|(rd<<7)|(((v+2048)>>12 & 0xfffff)<<12));
      if(lo)emit(0x1b|(rd<<7)|(rd<<15)|(((valueT)lo&4095)<<20));return; }
  /* Arithmetic shift without signed overflow, including UINT64_MAX and INT64_MIN. */
  hi=(v>>12)+((v&4095)>=2048);
  if(v>>63) hi|=(~(valueT)0)<<52;
  shift=12;
  while(!(hi&1)&&shift<63)
    { hi=(hi>>1)|(hi&((valueT)1<<63)); ++shift; }
  li(rd,hi);
  emit(0x1013|(rd<<7)|(rd<<15)|((valueT)shift<<20));
  if(lo)emit(0x13|(rd<<7)|(rd<<15)|(((valueT)lo&4095)<<20));
}
struct csr_name{const char *name;unsigned n;};
static const struct csr_name csrs[]={
 {"fflags",0},{"frm",1},{"fcsr",2},{"status",0x100},{"tl",0x101},
 {"tba",0x102},{"tpc",0x103},{"tstate",0x104},{"tt",0x105},
 {"tval",0x106},{"pil",0x107},{"ipend",0x108},{"scratch",0x109},
 {"ptbr",0x10a},{"timecmp",0x10b},{"cycle",0xc00},{"time",0xc01},
 {"instret",0xc02},{"features",0xd00},{"hartid",0xd01}};
static unsigned csr(char *s)
{ unsigned i; for(i=0;i<sizeof(csrs)/sizeof(csrs[0]);++i)if(!strcmp(s,csrs[i].name))return csrs[i].n; return imm(s,0,4095); }
static unsigned fence_set(char *s)
{
  unsigned n=0; char *p;
  if(!strcmp(s,"0"))return 0;
  for(;*s;++s){p=strchr("iorw",*s);if(!p){as_bad("invalid fence set");return 0;}n|=8>>(p-"iorw");}return n;
}
static int split(char *s,char **v)
{
  int n=0; char *next;
  if(!*trim(s))return 0;
  do { if(n==6){as_bad("too many operands");return n;} next=strchr(s,','); if(next)*next++=0;v[n++]=trim(s);s=next;}while(s);
  return n;
}
static void ga_assemble(char *line,unsigned depth);
static void expand(const char *name,const char *a,const char *b,const char *c,unsigned depth)
{
  char buf[512];
  snprintf(buf,sizeof(buf),"%s %s%s%s%s%s",name,a?a:"",b?",":"",b?b:"",c?",":"",c?c:"");
  ga_assemble(buf,depth+1);
}
static void ga_assemble(char *line,unsigned depth)
{
  char *name=trim(line),*args=name,*v[6],*suffix; unsigned i,w=0,aqrl=0;
  const struct ga_opcode *op=NULL; int n,k;
  if(depth>4){as_bad("pseudo recursion");return;}
  while(*args&&!ISSPACE(*args)) { *args=TOLOWER(*args); ++args; }
  if(*args)*args++=0; args=trim(args); n=split(args,v);
  suffix=strstr(name,".aqrl"); if(suffix&&suffix[5]==0){*suffix=0;aqrl=3;}
  else { suffix=strstr(name,".aq.rl"); if(suffix&&suffix[6]==0){*suffix=0;aqrl=3;}
    else { suffix=strstr(name,".aq"); if(suffix&&suffix[3]==0){*suffix=0;aqrl=2;}
      else {suffix=strstr(name,".rl");if(suffix&&suffix[3]==0){*suffix=0;aqrl=1;}}}}
  /* Small pseudos share checked parsing with the real instructions. */
  if(!strcmp(name,"li")&&n==2){expressionS e=ga_expr(v[1]);if(e.X_op!=O_constant)as_bad("li needs an absolute 64-bit constant");else li(regno(v[0],0),(valueT)e.X_add_number);return;}
  if((!strcmp(name,"la")&&n==2)||(!strcmp(name,"call")&&n==1))
    { unsigned rd=!strcmp(name,"call")?1:regno(v[0],0);expressionS e=ga_expr(v[n-1]);
      if(e.X_op!=O_symbol){as_bad("la/call requires symbol plus addend");return;}
      reloc_word(0x17|(rd<<7),&e,BFD_RELOC_GASPARDARC_PCREL_HI20);
      reloc_word((!strcmp(name,"call")?0x67:0x13)|(rd<<7)|(rd<<15),&e,BFD_RELOC_GASPARDARC_PCREL_LO12_I);return; }
  if(!strcmp(name,"nop")&&n==0){expand("addi","zero","zero","0",depth);return;}
  if(!strcmp(name,"ret")&&n==0){expand("jalr","zero","ra","0",depth);return;}
  if(!strcmp(name,"j")&&n==1){expand("jal","zero",v[0],NULL,depth);return;}
  if(!strcmp(name,"jr")&&n==1){expand("jalr","zero",v[0],"0",depth);return;}
  if(n==2)
    {
      if(!strcmp(name,"mv")){expand("addi",v[0],v[1],"0",depth);return;}
      if(!strcmp(name,"not")){expand("xori",v[0],v[1],"-1",depth);return;}
      if(!strcmp(name,"neg")){expand("sub",v[0],"zero",v[1],depth);return;}
      if(!strcmp(name,"seqz")){expand("sltiu",v[0],v[1],"1",depth);return;}
      if(!strcmp(name,"snez")){expand("sltu",v[0],"zero",v[1],depth);return;}
    }
  /* Generated simple pseudo dispatch follows. */
  if(!strcmp(name,"beqz")&&n==2){expand("beq",v[0],"zero",v[1],depth);return;}
  if(!strcmp(name,"bnez")&&n==2){expand("bne",v[0],"zero",v[1],depth);return;}
  if(!strcmp(name,"bltz")&&n==2){expand("blt",v[0],"zero",v[1],depth);return;}
  if(!strcmp(name,"bgez")&&n==2){expand("bge",v[0],"zero",v[1],depth);return;}
  if(!strcmp(name,"bgtz")&&n==2){expand("blt","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"blez")&&n==2){expand("bge","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"bgt")&&n==3){expand("blt",v[1],v[0],v[2],depth);return;}
  if(!strcmp(name,"ble")&&n==3){expand("bge",v[1],v[0],v[2],depth);return;}
  if(!strcmp(name,"bgtu")&&n==3){expand("bltu",v[1],v[0],v[2],depth);return;}
  if(!strcmp(name,"bleu")&&n==3){expand("bgeu",v[1],v[0],v[2],depth);return;}
  if(!strcmp(name,"fmv.s")&&n==2){expand("fsgnj.s",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"fneg.s")&&n==2){expand("fsgnjn.s",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"fabs.s")&&n==2){expand("fsgnjx.s",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"fmv.d")&&n==2){expand("fsgnj.d",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"fneg.d")&&n==2){expand("fsgnjn.d",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"fabs.d")&&n==2){expand("fsgnjx.d",v[0],v[1],v[1],depth);return;}
  if(!strcmp(name,"frcsr")&&n==1){expand("csrrs",v[0],"fcsr","zero",depth);return;}
  if(!strcmp(name,"frrm")&&n==1){expand("csrrs",v[0],"frm","zero",depth);return;}
  if(!strcmp(name,"frflags")&&n==1){expand("csrrs",v[0],"fflags","zero",depth);return;}
  if(!strcmp(name,"rdcycle")&&n==1){expand("csrrs",v[0],"cycle","zero",depth);return;}
  if(!strcmp(name,"rdtime")&&n==1){expand("csrrs",v[0],"time","zero",depth);return;}
  if(!strcmp(name,"rdinstret")&&n==1){expand("csrrs",v[0],"instret","zero",depth);return;}
  if(!strcmp(name,"rdfeatures")&&n==1){expand("csrrs",v[0],"features","zero",depth);return;}
  if(!strcmp(name,"fscsr")&&n==1){expand("csrrw","zero","fcsr",v[0],depth);return;}
  if(!strcmp(name,"fscsr")&&n==2){expand("csrrw",v[0],"fcsr",v[1],depth);return;}
  if(!strcmp(name,"fsrm")&&n==1){expand("csrrw","zero","frm",v[0],depth);return;}
  if(!strcmp(name,"fsrm")&&n==2){expand("csrrw",v[0],"frm",v[1],depth);return;}
  if(!strcmp(name,"fsflags")&&n==1){expand("csrrw","zero","fflags",v[0],depth);return;}
  if(!strcmp(name,"fsflags")&&n==2){expand("csrrw",v[0],"fflags",v[1],depth);return;}
  if(!strcmp(name,"csrr")&&n==2){expand("csrrs",v[0],v[1],"zero",depth);return;}
  if(!strcmp(name,"csrw")&&n==2){expand("csrrw","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"csrs")&&n==2){expand("csrrs","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"csrc")&&n==2){expand("csrrc","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"csrwi")&&n==2){expand("csrrwi","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"csrsi")&&n==2){expand("csrrsi","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"csrci")&&n==2){expand("csrrci","zero",v[0],v[1],depth);return;}
  if(!strcmp(name,"ei")&&n==0){expand("csrrsi","zero","status","1",depth);return;}
  if(!strcmp(name,"di")&&n==0){expand("csrrci","zero","status","1",depth);return;}
  if(!strcmp(name,"wrptbr")&&n==1){expand("csrrw","zero","ptbr",v[0],depth);return;}
  if(!strcmp(name,"jal")&&n==1){expand("jal","ra",v[0],NULL,depth);return;}
  if(!strcmp(name,"jalr"))
    {
      if(n==1){expand("jalr","ra",v[0],"0",depth);return;}
      if(n==2&&strchr(v[1],'('))
        {char *q=strchr(v[1],'('),*e=strchr(q,')'); if(!e||e[1]){as_bad("invalid jalr address");return;}*q++=0;*e=0;expand("jalr",v[0],q,*v[1]?v[1]:"0",depth);return;}
    }
  if(!strcmp(name,"tlbflush")&&n<2){expand("tlbflush",n?v[0]:"zero","zero",NULL,depth);return;}
  if(!strcmp(name,"fence")&&n==0){expand("fence","iorw","iorw",NULL,depth);return;}
  for(i=0;i<ga_num_opcodes;++i)if(!strcmp(name,ga_opcodes[i].name)){op=&ga_opcodes[i];break;}
  if(!op){as_bad("unknown instruction or invalid pseudo `%s'",name);return;}
  if(aqrl&&(op->match&0x7f)!=0x2f){as_bad("aq/rl suffix requires atomic instruction");return;}
  w=op->match|(aqrl<<25);
  {
    char fmt[100],*f[6];int need; expressionS target; int has_target=0;
    strcpy(fmt,op->args);need=split(fmt,f);
    if(need&& !strcmp(f[need-1],"rm")&&n==need-1)v[n++]="dyn";
    if(n!=need){as_bad("%s expects %s",name,op->args);return;}
    for(k=0;k<n;++k)
      {
        char *t=f[k], *s=v[k]; unsigned val=0,shift=0;
        if(strstr(t,"(rs1)"))
          {
            char *q=strchr(s,'('),*e=q?strchr(q,')'):NULL;offsetT d=0;
            if(!q||!e||e[1]){as_bad("expected offset(base)");return;}*q++=0;*e=0;
            if(strncmp(t,"imm12",5)==0)d=*s?imm(s,-2048,2047):0;
            else if(*s){as_bad("atomic/cache address must be (base)");return;}
            w|=regno(q,0)<<15;
            if((w&0x7f)==0x23||(w&0x7f)==0x27)w|=((d&0xfe0)<<20)|((d&31)<<7);
            else w|=((valueT)d&4095)<<20;
            continue;
          }
        if(!strcmp(t,"label")){target=ga_expr(s);has_target=1;continue;}
        if(!strcmp(t,"csr")){val=csr(s);shift=20;}
        else if(!strcmp(t,"imm12")){val=imm(s,-2048,2047)&4095;shift=20;}
        else if(!strcmp(t,"imm20")){val=imm(s,-524288,1048575)&0xfffff;shift=12;}
        else if(!strcmp(t,"shamt6")){val=imm(s,0,63);shift=20;}
        else if(!strcmp(t,"shamt5")){val=imm(s,0,31);shift=20;}
        else if(!strcmp(t,"uimm5")){val=imm(s,0,31);shift=15;}
        else if(!strcmp(t,"imm8")){val=imm(s,0,255);shift=20;}
        else if(!strcmp(t,"rm"))
          { static const char *const rms[]={"rne","rtz","rdn","rup","rmm","reserved5","reserved6","dyn"};
            for(val=0;val<8;++val)if(!strcmp(s,rms[val]))break;
            if(val==5||val==6||val==8){as_bad("invalid rounding mode");return;}shift=12; }
        else if(!strcmp(t,"pred")||!strcmp(t,"succ")){val=fence_set(s);shift=!strcmp(t,"pred")?24:20;}
        else if(!strcmp(t,"constante"))
          {static const char *const fs[]={"0.0","1.0","-1.0","0.5","2.0","0.25","4.0","0.125","8.0","16.0","0.0625","3.0","1.5","0.75","inf","-inf","nan"};
            for(val=0;val<17;++val)if(!strcmp(s,fs[val]))break;
            if(val==17){as_bad("unsupported FLI constant");return;}shift=15;}
        else {val=regno(s,t[0]=='f');shift=(!strcmp(t,"rd")||!strcmp(t,"fd"))?7:(!strcmp(t,"rs1")||!strcmp(t,"fs1"))?15:!strcmp(t,"fs3")?27:20;}
        w|=(unsigned long)val<<shift;
      }
    if(has_target)
      {
        bfd_reloc_code_real_type code=(w&0x7f)==0x6f?BFD_RELOC_GASPARDARC_JAL:BFD_RELOC_GASPARDARC_BRANCH;
        if(target.X_op==O_constant)
          { offsetT d=target.X_add_number,q=d/4;
            if((d&3)||q<((w&0x7f)==0x6f?-524288:-2048)||q>((w&0x7f)==0x6f?524287:2047)){as_bad("branch offset out of range or unaligned");return;}
            if((w&0x7f)==0x6f)w|=((valueT)q&0xfffff)<<12;
            else w|=(((valueT)q&0xfe0)<<20)|(((valueT)q&31)<<7);
            emit(w);
          }
        else if(target.X_op==O_symbol)reloc_word(w,&target,code);
        else as_bad("branch target requires symbol plus addend or displacement");
      }
    else emit(w);
  }
}
void md_assemble(char *s){ga_assemble(s,0);}
long md_pcrel_from(fixS *f){return f->fx_frag->fr_address+f->fx_where;}
void md_apply_fix(fixS *f,valueT *v,segT seg ATTRIBUTE_UNUSED)
{
  if(f->fx_addsy) {f->fx_done=0;return;}
  if(f->fx_r_type==BFD_RELOC_8||f->fx_r_type==BFD_RELOC_16||f->fx_r_type==BFD_RELOC_32||f->fx_r_type==BFD_RELOC_64)
    {md_number_to_chars(f->fx_frag->fr_literal+f->fx_where,*v,f->fx_size);f->fx_done=1;}
  else as_bad_where(f->fx_file,f->fx_line,"unsupported absolute fixup");
}
arelent *tc_gen_reloc(asection *sec ATTRIBUTE_UNUSED,fixS *f)
{
  arelent *r;
  if(f->fx_subsy){as_bad_where(f->fx_file,f->fx_line,"symbol subtraction cannot be relocated");return NULL;}
  r=XNEW(arelent);r->sym_ptr_ptr=XNEW(asymbol *);
  *r->sym_ptr_ptr=symbol_get_bfdsym(f->fx_addsy);
  r->address=f->fx_frag->fr_address+f->fx_where;r->addend=f->fx_offset;
  r->howto=bfd_reloc_type_lookup(stdoutput,f->fx_r_type);
  if(!r->howto){as_bad_where(f->fx_file,f->fx_line,"unsupported relocation");free(r->sym_ptr_ptr);free(r);return NULL;}
  return r;
}
