#undef TARGET_OS_CPP_BUILTINS
#define TARGET_OS_CPP_BUILTINS() \
  do { builtin_define ("__gaspardos__"); \
       builtin_assert ("system=gaspardos"); } while (0)
 
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s crtbegin.o%s"
#undef ENDFILE_SPEC
#define ENDFILE_SPEC "crtend.o%s"
#undef LIB_SPEC
#define LIB_SPEC "--start-group -lc -lgaspardos -lgcc --end-group"
#undef LINK_SPEC
#define LINK_SPEC "-static"
