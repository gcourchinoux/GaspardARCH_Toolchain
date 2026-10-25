/* GPL-3.0-or-later. */
extern bool gaspardarc_regno_ok_for_base (unsigned int, bool);
#ifdef RTX_CODE
extern void gaspardarc_print_operand (FILE *, rtx, int);
extern void gaspardarc_print_address (FILE *, rtx);
extern void gaspardarc_expand_move (rtx *);
extern const char *gaspardarc_output_move (rtx *);
extern void gaspardarc_expand_prologue (void);
extern void gaspardarc_expand_epilogue (void);
#endif
