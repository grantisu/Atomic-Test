CFLAGS := -Wall -std=c99 -O1 -fopenmp $(CFLAGS)

SRC := inc.c
PROG := inc
EXTRA_PROG := inc_int64 inc_float inc_double

all: $(PROG)

.PHONY: test clean

inc_int64: $(SRC)
	$(CC) -DVARTYPE=int64_t $(CFLAGS) $(LDFLAGS) $< -o $@

inc_float: $(SRC)
	$(CC) -DVARTYPE=float $(CFLAGS) $(LDFLAGS) $< -o $@

inc_double: $(SRC)
	$(CC) -DVARTYPE=double $(CFLAGS) $(LDFLAGS) $< -o $@

MINTIME = 0.15
ITERS   = 500
THREADS = 1 2 3 4
VARS    = 1 32
STRIDE  = 1
RANDOM  = 0
ATOMIC  = 0 1

test: all
	@echo MINTIME: $(MINTIME) >&2
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
	          env OMP_NUM_THREADS=$$tcnt ./$(PROG) $(MINTIME) $(ITERS) $$var $$stride $$rand $$atomic ; \
	        done ; \
	      done ; \
	    done ; \
	  done ; \
	done

stdreport: all
	@$(MAKE) --quiet  \
	THREADS='1 2 3 4' \
	MINTIME=0.25 \
	VARS="$$(seq -s ' ' 1 32) $$(seq -s ' ' 40 8 128) $$(seq -s ' ' 192 64 512) $$(seq -s ' ' 768 256 2048) $$(seq -s ' ' 2560 512 8192)" \
	STRIDE='1 2 4 8 16 32 64 1024' \
	test | tee $@

quickreport: all
	@$(MAKE) --quiet  \
	THREADS='1 2 4' \
	MINTIME=0.25 \
	VARS="$$(seq -s ' ' 1 32) $$(seq -s ' ' 40 8 128) $$(seq -s ' ' 192 64 512) $$(seq -s ' ' 768 256 2048) $$(seq -s ' ' 2560 512 8192)" \
	STRIDE='1 16 1024' \
	test | tee $@

clean:
	@-rm $(PROG) $(EXTRA_PROG)

