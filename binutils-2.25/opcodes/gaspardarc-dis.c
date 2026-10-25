/* GaspardARC disassembler. GPL-3.0-or-later. */
#include "sysdep.h"
#include "dis-asm.h"
#include "opcode/gaspardarc.h"
static bfd_signed_vma sx (bfd_vma v, unsigned n)
{ return (bfd_signed_vma) ((v ^ ((bfd_vma) 1 << (n-1))) - ((bfd_vma) 1 << (n-1))); }
int print_insn_gaspardarc (bfd_vma pc, disassemble_info *info)
{
  bfd_byte bytes[4]; unsigned long w; unsigned i, j;
  int err = info->read_memory_func (pc, bytes, 4, info);
  if (err) { info->memory_error_func (err, pc, info); return -1; }
  w = bfd_getl32 (bytes);
  for (i=0; i<ga_num_opcodes; ++i)
    if ((w & ga_opcodes[i].mask) == ga_opcodes[i].match)
      {
        const struct ga_opcode *op = &ga_opcodes[i];
        char args[100], *t, *next; int first=1;
        info->fprintf_func (info->stream, "%s", op->name);
        if ((w & 0x7f)==0x2f)
          { if (w & (1UL<<26)) info->fprintf_func(info->stream,".aq");
            if (w & (1UL<<25)) info->fprintf_func(info->stream,".rl"); }
        strcpy(args,op->args);
        for (t=args; t && *t; t=next)
          {
            next=strchr(t,','); if(next) *next++=0;
            while(*t==' ') ++t;
            info->fprintf_func(info->stream,first?"\t":", "); first=0;
            if (strstr(t,"(rs1)"))
              {
                if (strncmp(t,"imm12",5)==0)
                  info->fprintf_func(info->stream,"%ld",(long)sx(
                    ((w&0x7f)==0x23 || (w&0x7f)==0x27)
                    ? ((w>>25)<<5)|((w>>7)&31) : w>>20,12));
                info->fprintf_func(info->stream,"(%s)",ga_gpr_names[(w>>15)&31]);
              }
            else if (!strcmp(t,"label"))
              {
                bfd_signed_vma d = (w&0x7f)==0x6f ? sx(w>>12,20)*4
                  : sx(((w>>25)<<5)|((w>>7)&31),12)*4;
                info->print_address_func(pc+d,info);
              }
            else if (!strcmp(t,"rm"))
              { static const char *const rm[]={"rne","rtz","rdn","rup","rmm","reserved5","reserved6","dyn"};
                info->fprintf_func(info->stream,"%s",rm[(w>>12)&7]); }
            else if (!strcmp(t,"csr")) info->fprintf_func(info->stream,"0x%lx",w>>20);
            else if (!strcmp(t,"imm20")) info->fprintf_func(info->stream,"0x%lx",w>>12);
            else if (!strcmp(t,"imm12")) info->fprintf_func(info->stream,"%ld",(long)sx(w>>20,12));
            else if (!strcmp(t,"imm8")) info->fprintf_func(info->stream,"%lu",(w>>20)&255);
            else if (!strcmp(t,"shamt6") || !strcmp(t,"shamt5")) info->fprintf_func(info->stream,"%lu",(w>>20)&(!strcmp(t,"shamt6")?63:31));
            else if (!strcmp(t,"uimm5")) info->fprintf_func(info->stream,"%lu",(w>>15)&31);
            else if (!strcmp(t,"constante"))
              { static const char *const fli[]={"0.0","1.0","-1.0","0.5","2.0","0.25","4.0","0.125","8.0","16.0","0.0625","3.0","1.5","0.75","inf","-inf","nan"};
                j=(w>>15)&31; info->fprintf_func(info->stream,"%s",j<17?fli[j]:"reserved"); }
            else if (!strcmp(t,"pred") || !strcmp(t,"succ"))
              { unsigned f=(w>>(!strcmp(t,"pred")?24:20))&15;
                if(!f) info->fprintf_func(info->stream,"0");
                for(j=0;j<4;++j) if(f&(8>>j)) info->fprintf_func(info->stream,"%c","iorw"[j]); }
            else
              { unsigned shift= (!strcmp(t,"rd")||!strcmp(t,"fd"))?7:
                  (!strcmp(t,"rs1")||!strcmp(t,"fs1"))?15:!strcmp(t,"fs3")?27:20;
                info->fprintf_func(info->stream,"%s",t[0]=='f'?ga_fpr_names[(w>>shift)&31]:ga_gpr_names[(w>>shift)&31]); }
          }
        return 4;
      }
  info->fprintf_func(info->stream,".word\t0x%08lx",w); return 4;
}
