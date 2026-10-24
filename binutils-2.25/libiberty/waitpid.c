/*

@deftypefn Supplemental int waitpid (int @var{pid}, int *@var{status}, int)

This is a wrapper around the @code{wait} function.  Any ``special''
values of @var{pid} depend on your implementation of @code{wait}, as
does the return value.  The third argument is unused in @libib{}.

@end deftypefn

*/

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "ansidecl.h"

/* On some systems (such as WindISS), you must include <sys/types.h>
   to get the definition of "pid_t" before you include <sys/wait.h>.  */
#include <sys/types.h>

#ifdef __MINGW32__
#include <process.h>
#endif

#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

pid_t
waitpid (pid_t pid, int *stat_loc, int options ATTRIBUTE_UNUSED)
{
#ifdef __MINGW32__
  /* The Windows CRT waits for child process handles returned by spawn.  */
  return (pid_t) _cwait (stat_loc, (intptr_t) pid, _WAIT_CHILD);
#else
  for (;;)
    {
      int wpid = wait(stat_loc);
      if (wpid == pid || wpid == -1)
	return wpid;
    }
#endif
}
