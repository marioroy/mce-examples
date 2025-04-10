chameneos-redux-examples
========================

An adaptation of ["Chameneos, a Concurrency Game for Java, Ada, and Others"](https://cedric.cnam.fr/PUBLIS/RC474.pdf) using Perl.

The Chameneos benchmark is a synchronization problem. Each program should:

* Create differently coloured (blue, red, yellow), differently named, concurrent chameneos creatures.
* Each creature will repeatedly go to the meeting place and meet, or wait to meet, another chameneos "(at the request the caller does not know whether another chameneos is already present or not, neither if there will be one in some future)".
* Both creatures will change colour to complement the colour of the chameneos that they met - don't use arithmetic to complement the colour, use if-else or switch/case or pattern-match.
* Write all the colour changes for blue red and yellow creatures, using the colour complement function.
* For rendezvouses with an odd number of creatures (blue red yellow) and with an even number of creatures (blue red yellow red yellow blue red yellow red blue).
  1. write the colours the creatures start with
  2. after N meetings have taken place, for each creature write the number of creatures met and spell out the number of times the creature met a creature with the same name (should be zero)
  3. spell out the sum of the number of creatures met (should be 2N)

Dependencies:

```text
  Perl MCE 1.839, MCE::Shared 1.841 minimally
  Sereal::Encode 3.015, Sereal::Decode 3.015 minimally (optional)
  threads, threads::shared (threading optional)
  Python 3
```

Files:

```text
  rodrigo.pl    Thread::Semaphore, concurrency via threads
  pipe1.pl      MCE::Channel::PipeFast, concurrency via threads
  pipe2.pl      MCE::Channel::PipeFast, concurrency via MCE::Child
  pipe2.py      Python demonstration, concurrency via multiprocessing
  channel1.pl   MCE::Channel::SimpleFast, concurrency via threads
  channel2.pl   MCE::Channel::SimpleFast, concurrency via MCE::Child
  channel2.py   Python demonstration, concurrency via multiprocessing
  condvar1.pl   MCE::Shared using the TIE interface
  condvar2.pl   MCE::Shared using the OO interface
  inbox1.pl     MCE::Inbox, concurrency via threads
  inbox2.pl     MCE::Inbox, concurrency via MCE::Hobo
  lib           MCE::Inbox package resides here
```

Running:

```text
  perl rodrigo.pl  6000

  perl pipe1.pl    6000  # requires Perl 5.8 minimally
  perl pipe2.pl    6000
  perl channel1.pl 6000
  perl channel2.pl 6000

  perl condvar1.pl 6000  # requires Perl 5.10.1 minimally
  perl condvar2.pl 6000
  perl inbox1.pl   6000
  perl inbox2.pl   6000

  python pipe2.py  6000    # synchronization via os pipes
  python channel2.py 6000  # synchronization via socketpairs
```

Output:

```text
$ perl pipe2.pl 600000

blue + blue -> blue
blue + red -> yellow
blue + yellow -> red
red + blue -> yellow
red + red -> red
red + yellow -> blue
yellow + blue -> red
yellow + red -> blue
yellow + yellow -> yellow

 blue red yellow
400982 zero
399390 zero
399628 zero
 one two zero zero zero zero zero

 blue red yellow red yellow blue red yellow red blue
119964 zero
120028 zero
120033 zero
120048 zero
120047 zero
119731 zero
120045 zero
120036 zero
120037 zero
120031 zero
 one two zero zero zero zero zero

duration: 7.695 seconds
```

See Also:

  * [A backup mirror of benchmarksgame](https://github.com/madnight/benchmarksgame)
  * [A performance evaluation of concurrent programming with the Swift actor model](https://www.diva-portal.org/smash/get/diva2:1732390/FULLTEXT01.pdf)
  * [An Efficient Implementation of Guard-based Synchronization for an Object-Oriented Programming Language](https://macsphere.mcmaster.ca/bitstream/11375/25567/2/Yao_Shucai_202007_PhD.pdf)
  * [Perl threads-lite chameneos-redux example](https://github.com/Leont/threads-lite/blob/master/examples/chameneos)

