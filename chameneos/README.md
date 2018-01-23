chameneos-redux-examples
========================

An adaptation of ["Chameneos, a Concurrency Game for Java, Ada, and Others"](http://benchmarksgame.alioth.debian.org/u64q/chameneosredux-description.html#chameneosredux) using Perl.

The `inbox1.pl` example requires Thread::Queueu 3.07 or later.

Files

  * condvar1.pl  (MCE::Shared using TIE interface)
  * condvar2.pl  (MCE::Shared using OO interface)
  * inbox1.pl    (MCE::Inbox, concurrency via threads)
  * inbox2.pl    (MCE::Inbox, concurrency via MCE::Hobo)

Dir

  * lib  (contains MCE::Inbox supporting threads and processes)

See Also

  * [chameneos-redux Perl #4 program](http://benchmarksgame.alioth.debian.org/u64q/program.php?test=chameneosredux&lang=perl&id=4)
  * [threads-lite chameneos-redux example](https://github.com/Leont/threads-lite/blob/master/examples/chameneos)

