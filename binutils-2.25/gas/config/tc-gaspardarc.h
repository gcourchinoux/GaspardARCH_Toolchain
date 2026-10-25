/* GaspardARC GAS target. GPL-3.0-or-later. */
#define TC_GASPARDARC 1
#define TARGET_BYTES_BIG_ENDIAN 0
#define TARGET_FORMAT "elf64-gaspardarc"
#define TARGET_ARCH bfd_arch_gaspardarc
#define WORKING_DOT_WORD
#define md_undefined_symbol(NAME) 0
#define md_section_align(SEG,SIZE) (SIZE)
#define md_estimate_size_before_relax(A,B) (as_fatal ("no relaxation"), 0)
#define md_convert_frag(B,S,F) as_fatal ("no relaxation")
#define MD_PCREL_FROM_SECTION(FIX,SEC) md_pcrel_from (FIX)
extern long md_pcrel_from (struct fix *);
#define tc_fix_adjustable(FIX) 0
#define TC_FORCE_RELOCATION(FIX) ((FIX)->fx_addsy != NULL)
