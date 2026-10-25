/* GaspardARC Risc64 architecture.  GPL-3.0-or-later.  */
#include "sysdep.h"
#include "bfd.h"
#include "libbfd.h"
const bfd_arch_info_type bfd_gaspardarc_arch =
{ 64, 64, 8, bfd_arch_gaspardarc, 0, "gaspardarc", "gaspardarc",
  2, TRUE, bfd_default_compatible, bfd_default_scan, bfd_arch_default_fill, NULL };
