## Many-Core Engine for Perl - Examples

Various examples, not included with the Perl MCE distribution, are saved here.
They are organized into sub-directories.

    asynchrony/ dnslookup_ae.pl, dnslookup_ioa.pl, echoserver_ae.pl,
        echoserver_ioa.pl, echoserver_mojo.pl, echoserver_poe.pl,
        Parallel concurrency, asynchrony, and shared data.

    asynchrony/ fastping_ae.pl
        Report failed IP addresses to standard output.

    biofasta/ fasta_aidx.pl, fasta_rdr*.pl
        Parallel demonstration for Bioinformatics.

    chameneos/ channel*.pl, condvar*.pl, inbox*.pl
        Various adaptations of "Chameneos, a Concurrency Game" using Perl.

    fibonacci/ fibprime-hobo.pl, fibprime-mce.pl, fibprime-threads.pl
        Math::Prime::Util parallel demonstrations

    framebuffer/ *chnl_primitives.pl, *hobo_primitives.pl, *hobo_slideshow.pl
        Graphics::Framebuffer parallel demonstrations

    gearman/ reverse_client*.pl, reverse_worker*.pl (using non-XS module)
        Gearman + MCE parallel demonstrations

    gearman_xs/ reverse_client*.pl, reverse_worker*.pl (using XS module)
        Gearman::XS + MCE parallel demonstrations

    matmult/ matmult_base*.pl, matmult_mce*.pl, strassen_mce*.pl
        Various matrix multiplication demonstrations benchmarking
        PDL, PDL + MCE, as well as parallelizing Strassen's
        divide-and-conquer algorithm. Included are 2 plain
        Perl examples.

    network/ net_pcap*.pl, ping*.pl
        Various manager-producer consumer demonstrations.

    sampledb/ create.pl, query*.pl, update*.pl
        Examples demonstrating DBI (SQLite) with MCE.

    tbray/ wf_mce1.pl, wf_mce2.pl, wf_mce3.pl
        An implementation of wide finder utilizing MCE.
        As fast as MMAP IO when file resides in OS FS cache.
        2x ~ 3x faster when reading directly from disk.

The rest are placed inside the "other" directory.

    cat.pl, egrep.pl, wc.pl
        Concatenation, egrep, and word count scripts similar to the
        cat, egrep, and wc binaries respectively.

    files_flow.pl, files_mce.pl, files_thr.pl
        Demonstrates MCE::Flow, MCE::Queue, and Thread::Queue.
        See MCE::Queue synopsis for another variation.

    findnull.pl
        A parallel script for reporting lines containing null fields.
        It is many times faster than the egrep binary. Try this against
        a large file containing very long lines.

    flow_demo.pl, flow_model.pl
        Demonstrates MCE::Flow, MCE::Queue, and MCE->gather.

    foreach.pl, forseq.pl, forchunk.pl
        These examples demonstrate the sqrt example from Parallel::Loops
        (Parallel::Loops v0.07 utilizing Parallel::ForkManager v1.07).

        Testing was on a Linux VM; Perl v5.20.1; Haswell i7 at 2.6 GHz.
        The number indicates the size of input displayed in 1 second.
        Output was directed to >/dev/null.

        Parallel::Loops:     1,600  Forking each @input is expensive
        MCE->foreach...:    30,000  Workers persist between each @input
        MCE->forseq....:   150,000  Uses sequence of numbers as input
        MCE->forchunk..:   800,000  IPC overhead is greatly reduced

    interval.pl, mutex.pl, relay.pl
        Demonstration of the interval option appearing in MCE 1.5.
        Mutex locking and relaying data among workers.

    iterator.pl
        Similar to forseq.pl. Specifies an iterator for input_data.
        A factory function is called which returns a closure.

    pipe1.pl, pipe2.pl
        Process STDIN or FILE in parallel. Processing is via Perl for
        pipe1.pl, whereas an external command for pipe2.pl.

    seq_demo.pl, step_demo.pl, step_model.pl, step_mon.pl
        Demonstration of the new sequence option appearing in MCE 1.3.
        Run with seq_demo.pl | sort

        Transparent use of MCE::Queue with MCE::Step.

    shared_mce.pl, shared_thr.pl
        Data sharing via MCE::Shared and threads::shared.

    sync.pl, utf8.pl
        Barrier synchronization demonstration.
        Process input containing unicode data.

### Copyright and Licensing

Copyright (C) 2012-2022 by Mario E. Roy <marioeroy AT gmail DOT com>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself:

        a) the GNU General Public License as published by the Free
        Software Foundation; either version 1, or (at your option) any
        later version, or

        b) the "Artistic License" which comes with this Kit.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
Kit, in the file named "Artistic".  If not, I'll be glad to provide one.

You should also have received a copy of the GNU General Public License
along with this program in the file named "Copying". If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA or visit their web page on the internet at
http://www.gnu.org/copyleft/gpl.html.

