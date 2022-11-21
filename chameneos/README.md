chameneos-redux-examples
========================

An adaptation of ["Chameneos, a Concurrency Game for Java, Ada, and Others"](https://cedric.cnam.fr/PUBLIS/RC474.pdf) using Perl.

Dependencies:

  * MCE 1.839, MCE::Shared 1.841 minimally
  * Sereal::Encode 3.015, Sereal::Decode 3.015 minimally (optional)
  * threads, threads::shared (threading optional)

Files:

  * rodrigo.pl   - Thread::Semaphore, concurrency via threads
  * channel1.pl  - MCE::Channel::SimpleFast, concurrency via threads
  * channel2.pl  - MCE::Channel::SimpleFast, concurrency via MCE::Child
  * condvar1.pl  - MCE::Shared using the TIE interface
  * condvar2.pl  - MCE::Shared using the OO interface
  * inbox1.pl    - MCE::Inbox, concurrency via threads
  * inbox2.pl    - MCE::Inbox, concurrency via MCE::Hobo
  * lib          - MCE::Inbox package resides here

Running:

  * perl rodrigo.pl  6000

  * perl channel1.pl 6000  # require Perl 5.8 minimally
  * perl channel2.pl 6000

  * perl condvar1.pl 6000  # require Perl 5.10.1 minimally
  * perl condvar2.pl 6000
  * perl inbox1.pl   6000
  * perl inbox2.pl   6000

See Also:

  * [threads-lite chameneos-redux example](https://github.com/Leont/threads-lite/blob/master/examples/chameneos)

