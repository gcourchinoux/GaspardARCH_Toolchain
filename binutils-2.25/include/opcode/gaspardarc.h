/* GaspardARC opcode interface. GPL-3.0-or-later. */
#ifndef OPCODE_GASPARDARC_H
#define OPCODE_GASPARDARC_H
struct ga_opcode { const char *name, *args; unsigned long mask, match; };
extern const struct ga_opcode ga_opcodes[];
extern const unsigned int ga_num_opcodes;
extern const char *const ga_gpr_names[32];
extern const char *const ga_fpr_names[32];
#endif
