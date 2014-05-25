Atomic Test
===========

This is a tiny C project I wrote to explore the caching behavior of multicore
systems. I wrote it after reading about [flat combining](
http://www.cs.bgu.ac.il/~hendlerd/papers/flat-combining.pdf ) data structures,
in order to explore when single-threaded execution outperforms multi-threaded
execution at a low level on [\*nix]( http://en.wikipedia.org/wiki/Unix-like )
systems.


Overview
--------

By default, running `make all` produces one program—`inc`—which only
measures one thing: how long it takes to increment integers. For example, the
following invocation:

    env OMP_NUM_THREADS=$THREADS ./inc $TIME $ITERS $INTS $STRIDE $RAND $ATOMIC

with variables set to:

    THREADS=4
    TIME=0.25
    ITERS=15
    INTS=2
    STRIDE=3
    RAND=0
    ATOMIC=1

uses 4 [OpenMP]( http://openmp.org ) threads to atomically increment 2 integers
15 times each, where the integers are spaced 3 integer-lengths apart, and
accessed in linear order. This is repeated until the total execution time
exceeds 0.25 seconds, then the average nanoseconds per integer increment (minus
loop overhead) is reported.

The memory layout of the above scenario looks like this:

<!---
Markdown doesn't have good colspan support; resulting table should be:
|0x000|0x001|0x002|0x003|0x004|0x005|0x006|0x007|0x008|0x009|0x00a|0x00b|0x00c|0x00d|0x00e|0x00f|0x010|0x011|0x012|0x013|0x014|0x015|0x016|0x017|
| Data                  | Padding               | Padding               | Data                  | Padding               | Padding               |
|         Stride                                                        |        Stride                                                         |
-->
<table style="font-size: 80%; text-align: center;">
<tr style="font-size: 60%; min-width: 5em;">
<td style="border: 1px solid #000;">0x000</td>
<td style="border: 1px solid #000;">0x001</td>
<td style="border: 1px solid #000;">0x002</td>
<td style="border: 1px solid #000;">0x003</td>
<td style="border: 1px solid #000;">0x004</td>
<td style="border: 1px solid #000;">0x005</td>
<td style="border: 1px solid #000;">0x006</td>
<td style="border: 1px solid #000;">0x007</td>
<td style="border: 1px solid #000;">0x008</td>
<td style="border: 1px solid #000;">0x009</td>
<td style="border: 1px solid #000;">0x00a</td>
<td style="border: 1px solid #000;">0x00b</td>
<td style="border: 1px solid #000;">0x00c</td>
<td style="border: 1px solid #000;">0x00d</td>
<td style="border: 1px solid #000;">0x00e</td>
<td style="border: 1px solid #000;">0x00f</td>
<td style="border: 1px solid #000;">0x010</td>
<td style="border: 1px solid #000;">0x011</td>
<td style="border: 1px solid #000;">0x012</td>
<td style="border: 1px solid #000;">0x013</td>
<td style="border: 1px solid #000;">0x014</td>
<td style="border: 1px solid #000;">0x015</td>
<td style="border: 1px solid #000;">0x016</td>
<td style="border: 1px solid #000;">0x017</td>
</tr>
<tr style="background-color: #aff;">
<td style="border: 1px solid #000; background-color: #afa;" colspan=4>Data</td>
<td style="border: 1px solid #000;" colspan=4>Padding</td>
<td style="border: 1px solid #000;" colspan=4>Padding</td>
<td style="border: 1px solid #000; background-color: #afa;" colspan=4>Data</td>
<td style="border: 1px solid #000;" colspan=4>Padding</td>
<td style="border: 1px solid #000;" colspan=4>Padding</td>
</tr>
<tr style="background-color: #ffb;">
<td style="border: 1px solid #000;" colspan=12>Stride</td>
<td style="border: 1px solid #000;" colspan=12>Stride</td>
</tr>
</table>

The theory is that incrementing an integer is close to free on modern (i.e.
[superscalar]( http://en.wikipedia.org/wiki/Superscalar )) systems, and so most
of the time will be spent on memory access.  This can be seen by running the
following:

    for i in `seq 1 16 512` `seq 768 256 8196`; do
      env OMP_NUM_THREADS=1 ./inc 0.1 100 $i 1024 0 0
    done

and verifying that the reported latency correlates with the cache hierarchy.


Atomicity
---------

Currently, `inc.c` relies on [OpenMP]( http://openmp.org ) to provide
multithreading functionality and atomic increments. While this is fairly
portable and easy to code, it's not foolproof. With the x86 ISA, this C code:

    data[idx] += 1;

compiles (with `gcc -S -masm=intel -O1`) to something like:

    add	DWORD PTR [rax+rdx*4], 1

Adding the OpenMP atomic pragma:

    #pragma omp atomic
    data[idx] += 1;

produces minimal overhead; namely the `lock` prefix:

    lock add	DWORD PTR [rax+rdx*4], 1

This produces the expected results, and allows for reasonable comparisons
between single-threaded and multi-threaded runs.

Switching to the ARM ISA, the default assembly from gcc for the non-atomic case
is:

    ldr     r2, [r3, r5]
    add     r2, r2, #1
    str     r2, [r3, r5]

Adding the atomic pragma results in:

    bl      GOMP_atomic_start
    ldr     r3, [r5, r7]
    add     r3, r3, #1
    str     r3, [r5, r7]
    bl      GOMP_atomic_end

which adds two function calls right in the hot path. This is extremely unfair
to the atomic case, and does not produce reasonable results. This can be
(mostly) fixed by letting GCC know that it can target modern ARM chips
(`gcc -march=armv7-a`), thus generating:

    dmb     sy
    .LSYT354:
    ldrex   r3, [r5]
    add     r3, r3, r9
    strex   r2, r3, [r5]
    teq     r2, #0
    bne     .LSYT354
    .LSYB354:
    dmb     sy

which produces mostly decent results.

As a quick aside, this is an excellent example of [RISC](
http://en.wikipedia.org/wiki/Reduced_instruction_set_computing ) vs [CISC](
http://en.wikipedia.org/wiki/Complex_instruction_set_computer ) architectures:
the CISC (x86) ISA adds complex synchronization functionality with a single
byte prefix, whereas the RISC (ARM) ISA requires multiple, explicit
instructions (including a retry loop!) to accomplish approximately the same
thing.

`CFLAGS` can be edited in the Makefile, or passed in from the environment:

    CFLAGS='-march=armv7-a' make


Producing Results
-----------------

To quickly check things, run `make test`. All the input parameters are echoed
to stderr, and the results (with headers) are printed to stdout. If everything
looks good, running `make tinyreport` (and waiting five minutes) will produce a
CSV file with more extensive results. `make stdreport` will take much longer,
and produce more robust results; additional make targets can be added as
necessary.

