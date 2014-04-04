CFLAGS := -std=c99 -O1 -fopenmp $(CFLAGS)

SRC := inc.c
PROGS := inc_lock inc_nolock

all: $(PROGS)

.PHONY: test clean

inc_lock: $(SRC)
	$(CC) -DATOMIC $(CFLAGS) $(LDFLAGS) $< -o $@

inc_nolock: $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

ITERS   = 10000
THREADS = 1 2 3 4
VARS    = 32
STRIDE  = 1

test: all
	@echo ITERS: $(ITERS) >&2
	@echo PROGS: $(PROGS) >&2
	@echo THREADS: $(THREADS) >&2
	@echo VARS: $(VARS) >&2
	@echo STRIDE: $(STRIDE) >&2
	@echo Prog,Threads,Count,Stride,Time,Err
	@for prog in $(PROGS) ; do \
	  for tcnt in $(THREADS) ; do \
	    for var in $(VARS) ; do \
	      for stride in $(STRIDE) ; do \
	        echo -n "$$prog,$$tcnt,$$var,$$stride,"; env OMP_NUM_THREADS=$$tcnt ./$$prog $(ITERS) $$var $$stride ; \
	      done ; \
	    done ; \
	  done ; \
	done

stdreport: all
	@$(MAKE) --quiet  \
	THREADS='1 4' \
	ITERS=5000 \
	VARS="$$(seq -s ' ' 1 32) $$(seq -s ' ' 40 8 128) $$(seq -s ' ' 192 64 512)" \
	STRIDE='1 16 1024' \
	test | tee $@

clean:
	@-rm $(PROGS)

