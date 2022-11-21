
### Find Fibonacci primes in parallel, using Math::Prime::Util

It is January of 2016. It is with great joy in seeing MCE::Hobo,
parallelization supporting threads and processes, run as fast as
threads. The MCE example is my 2nd attempt which gathers Fibonacci
primes only. Thus, also running efficiently.

```
 fibprime-threads.pl  - threads/threads::shared [1]
 fibprime-hobo.pl     - MCE::Hobo/MCE::Shared
 fibprime-mce.pl      - Core MCE API
```

### Results from a dual Intel Xeon E5-2660 (v1) (32 logical cores)

```
 perl fibprime-threads.pl 32

    n27 (F14431) in  11.87429
    n28 (F25561) in  66.76433
    n29 (F30757) in 104.11877
    n30 (F35999) in 174.34042
    n31 (F37511) in 212.18519
    n32 (F50833) in 581.78776

 perl fibprime-hobo.pl 32

    n27 (F14431) in  11.61881
    n28 (F25561) in  66.27832
    n29 (F30757) in 104.78485
    n30 (F35999) in 174.48133
    n31 (F37511) in 213.91156
    n32 (F50833) in 582.53325

 perl fibprime-mce.pl 32

    n27 (F14431) in  11.43532
    n28 (F25561) in  65.63277
    n29 (F30757) in 103.93305
    n30 (F35999) in 174.04848
    n31 (F37511) in 213.78100
    n32 (F50833) in 577.86492
```

### References

1. ** Dana Jacobsen.
   https://metacpan.org/pod/Math::Prime::Util
   examples dir: fibprime-threads.pl

