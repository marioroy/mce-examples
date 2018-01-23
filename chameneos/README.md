chameneos-redux-examples
========================

An adaptation of ["Chameneos, a Concurrency Game for Java, Ada, and Others"](http://benchmarksgame.alioth.debian.org/u64q/chameneosredux-description.html#chameneosredux) using Perl.

Dependencies:

  * threads, threads::shared, and Thread::Queue 3.07 or later
  * Cygwin/UNIX OS'es: MCE 1.833 and MCE::Shared 1.834 or later
  * Microsoft Windows: MCE 1.834 and MCE::Shared 1.835 minimally

Files:

  * condvar1.pl  (MCE::Shared using TIE interface)
  * condvar2.pl  (MCE::Shared using OO interface)
  * inbox1.pl    (MCE::Inbox, concurrency via threads)
  * inbox2.pl    (MCE::Inbox, concurrency via MCE::Hobo)
  * lib          (contains MCE::Inbox supporting threads and processes)

Running:

  * perl condvar1.pl 6000
  * perl condvar2.pl 6000
  * perl inbox1.pl 6000
  * perl inbox2.pl 6000

See Also:

  * [chameneos-redux Perl #4 program](http://benchmarksgame.alioth.debian.org/u64q/program.php?test=chameneosredux&lang=perl&id=4)
  * [threads-lite chameneos-redux example](https://github.com/Leont/threads-lite/blob/master/examples/chameneos)

