CFLAGS := -Wall -std=c99 -O1 -fopenmp $(CFLAGS)

SRC := inc.c
PROG := inc

all: $(PROG)

.PHONY: test clean

inc_nolock: $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

inc_lock: $(SRC)
	$(CC) -DATOMIC $(CFLAGS) $(LDFLAGS) $< -o $@

LOOPS   = 20
ITERS   = 10000
THREADS = 1 2 3 4
VARS    = 32
STRIDE  = 1
RANDOM  = 0 1
ATOMIC  = 0 1

test: all
	@echo LOOPS: $(LOOPS) >&2
	@echo ITERS: $(ITERS) >&2
	@echo THREADS: $(THREADS) >&2
	@echo VARS: $(VARS) >&2
	@echo STRIDE: $(STRIDE) >&2
	@echo RANDOM: $(RANDOM) >&2
	@echo ATOMIC: $(ATOMIC) >&2
	@echo Atomic,Random,Threads,Stride,Count,Time
	@for atomic in $(ATOMIC) ; do \
	  for rand in $(RANDOM) ; do \
	    for tcnt in $(THREADS) ; do \
	      for stride in $(STRIDE) ; do \
	        for var in $(VARS) ; do \
	          env OMP_NUM_THREADS=$$tcnt ./$(PROG) $(LOOPS) $(ITERS) $$var $$stride $$rand $$atomic ; \
	        done ; \
	      done ; \
	    done ; \
	  done ; \
	done

stdreport: all
	@$(MAKE) --quiet  \
	THREADS='1 2 3 4' \
	LOOPS=1000 \
	ITERS=250 \
	VARS="$$(seq -s ' ' 1 32) $$(seq -s ' ' 40 8 128) $$(seq -s ' ' 192 64 512) $$(seq -s ' ' 768 256 2048) $$(seq -s ' ' 2560 512 8192)" \
	STRIDE='1 2 4 8 16 32 64 1024' \
	test | tee $@

quickreport: all
	@$(MAKE) --quiet  \
	THREADS='1 2 4' \
	LOOPS=1000 \
	ITERS=250 \
	VARS="$$(seq -s ' ' 1 32) $$(seq -s ' ' 40 8 128) $$(seq -s ' ' 192 64 512) $$(seq -s ' ' 768 256 2048) $$(seq -s ' ' 2560 512 8192)" \
	STRIDE='1 16 1024' \
	test | tee $@

clean:
	@-rm $(PROG)

