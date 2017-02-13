
## Perl + MCE + Gearman::XS Demonstrations

[Gearman](http://gearman.org) is an application framework allowing solutions
to farm out work to other machines. The included scripts demonstrate job
submissions to gearmand from a serial process and parallel using
[MCE](https://metacpan.org/pod/distribution/MCE/lib/MCE.pod) or
[MCE::Hobo](https://metacpan.org/pod/MCE::Hobo).

```
 reverse_client.pl
 reverse_client_mce.pl
 reverse_client_hobo.pl
```

Processing is handled by a given worker script, running serially and parallel
using MCE or MCE::Hobo.

```
 reverse_worker.pl
 reverse_worker_mce.pl
 reverse_worker_hobo.pl
```

### REQUIREMENTS

To run the examples, Perl is necessary obviously and various modules.

```
 MCE 1.811
 MCE::Shared 1.809
 Gearman::XS 0.15
 Perl::Unsafe::Signals 0.03
 Storable, installed with Perl, typically
```

The Gearman module is handled via the XS interface which is nice, of course.
Being an XS module may mean that signal-handling might not work as expected.
That is the case here. Fortunately, there is a remedy for that. The Unsafe module
is necessary in order to have the XS code respond to signal handling accordingly.
Its use is minimal at best. Without it, the script might not exit upon pressing
CTRL-C.

```perl
 # inside client script
 UNSAFE_SIGNALS {
    $ret = $client->run_tasks();
 };

 # inside worker script
 UNSAFE_SIGNALS {
    $ret = $worker->work();
 };

```

### RUNNING

1. Run the gearman server:

```
 gearmand --port=4730 &
```

2. Run any worker script in shell 1:

```
 perl reverse_worker.pl      -p 4730
 perl reverse_worker_mce.pl  -p 4730
 perl reverse_worker_hobo.pl -p 4730
```

3. Run any client script in shell 2:

```
 perl reverse_client.pl      -p 4730 string1 string2 ... stringN
 perl reverse_client_mce.pl  -p 4730 string1 string2 ... stringN
 perl reverse_client_hobo.pl -p 4730 string1 string2 ... stringN
```

The gist of it all is that compute nodes might be running fewer worker scripts
by running parallel themselves. An idea is running 1 worker script per 8 logical
cores. It is a way to relieve stress on gearmand as far as IPC and running on
many thousands of nodes.

