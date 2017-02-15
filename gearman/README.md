
## Perl + MCE + Gearman Demonstrations

This is the repository for testing MCE together with Gearman (non-XS) module.
MCE::Examples include samples using the non-XS and XS interface. Although the
API is not compatible between the two, the scripts residing here may run
interchangeably.

```
 perl mce-examples/gearman/reverse_worker.pl     # non-XS module
 perl mce-examples/gearman_xs/reverse_client.pl  # XS module
```

[Gearman](http://gearman.org) is an application framework allowing solutions
to farm out work to other machines. The included scripts demonstrate job
submissions to gearmand from a serial process and parallel using
[MCE](https://metacpan.org/pod/distribution/MCE/lib/MCE.pod) or
[MCE::Hobo](https://metacpan.org/pod/MCE::Hobo).

```
 reverse_client.pl
 reverse_client_mce.pl
 reverse_client_hobo.pl
 reverse_client_stdin.pl
```

Processing is handled by a given worker script, running serially and parallel
using MCE or MCE::Hobo.

```
 reverse_worker.pl
 reverse_worker_mce.pl
 reverse_worker_hobo.pl
 reverse_worker_persist.pl
```

### REQUIREMENTS

To run the examples, Perl is necessary obviously and various modules.

```
 MCE 1.812
 MCE::Shared 1.811
 Gearman 2.002.004
 Storable (installed with Perl, typically)
```

### RUNNING

Run the gearman server:

```
 gearmand --port=4730 &
```

Run any worker script in shell 1:

```
 perl reverse_worker.pl -p 4730
 perl reverse_worker_mce.pl -p 4730
 perl reverse_worker_hobo.pl -p 4730
 perl reverse_worker_persist.pl -p 4730
```

Run any client script in shell 2:

```
 perl reverse_client.pl -p 4730 string1 string2 ... stringN
 perl reverse_client_mce.pl -p 4730 string1 string2 ... stringN
 perl reverse_client_hobo.pl -p 4730 string1 string2 ... stringN
 perl reverse_client_stdin.pl -p 4730 < /usr/share/dict/words | wc -l
```

The gist of it all is that compute nodes might be running fewer worker scripts
by running parallel themselves. An idea is running 1 worker script per 8 logical
cores. It is a way to relieve stress on gearmand as far as IPC and running on
many thousands of nodes.

### EXERCISE

MCE workers are spawned one time in reverse_worker_persist.pl. Thus, workers
persist between runs. This wants a big input file. There is such a thing on
Linux.

Run the script where workers persist in shell 1:

```
 perl reverse_worker_persist.pl -p 4730
```

Run another, same script in shell 2:

```
 perl reverse_worker_persist.pl -p 4730
```

Run the client script supporting STDIN in shell 3:

```
 perl reverse_client_stdin.pl -p 4730 < /usr/share/dict/words | wc -l
```

Chunking is set to 4000 and 500 in the client and worker scripts respectively.
Mind you, the overall processing time is reasonably fast for half a million
words, less than a second.

Regards, Mario.

