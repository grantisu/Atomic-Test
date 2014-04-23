#define _POSIX_C_SOURCE 199309L

#include <omp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

struct timespec _dtime_t[2];
double dtime(void) {
	double r;
	clock_gettime(CLOCK_MONOTONIC, _dtime_t);
	r = (_dtime_t[0].tv_sec - _dtime_t[1].tv_sec) + 1e-9*(_dtime_t[0].tv_nsec - _dtime_t[1].tv_nsec);
	_dtime_t[1] = _dtime_t[0];
	return r;
}


#ifndef VARTYPE
#define VARTYPE int
#endif

static volatile int opt_hack;

int main(int argc, char **argv) {
	uint32_t loops = 15;
	uint32_t iters = 1000;
	uint32_t count = 10;
	uint32_t stride = 1;
	uint32_t random = 0;
	uint32_t atomic = 0;
	size_t data_sz;
	VARTYPE *data;
	uint32_t qseed, ridx=0;
	uint32_t print_everything=0;

	if (argc > 1)
		loops = atol(argv[1]);
	if (argc > 2)
		iters = atol(argv[2]);
	if (argc > 3)
		count = atol(argv[3]);
	if (argc > 4)
		stride = atol(argv[4]);
	if (argc > 5)
		random = atol(argv[5]);
	if (argc > 6)
		atomic = atol(argv[6]);
	
	data_sz = sizeof(VARTYPE) * count * stride;
	data = malloc(data_sz);

/* C99 _Pragma is good, but has problems */

#define PAR_FOR_TOP \
	_Pragma ("omp for") \
	for (int j=0; j < iters; j++) { \
		for (int i=0; i < count; i++) { \
			qseed = 1103515245*qseed + 12345;            \
			ridx = qseed % count;                        \
			uint32_t idx = (random ? ridx : i)*stride;
#define PAR_FOR_BOT \
		} \
	}

#define MAIN_FOR_TOP \
	_Pragma ("omp parallel private(qseed) reduction(&:ridx)") \
	{ \
		qseed = omp_get_thread_num(); \
		if (atomic) { \
			PAR_FOR_TOP

#define MAIN_FOR_MID \
			PAR_FOR_BOT \
		} else { \
			PAR_FOR_TOP

#define MAIN_FOR_BOT \
			PAR_FOR_BOT \
		} \
	}


	/* Measure average loop overhead */
	double overhead = 1e12;
	for (int k=0; k < loops; k++) {
		dtime();

		MAIN_FOR_TOP
			ridx += idx;
		MAIN_FOR_MID
			ridx -= idx;
		MAIN_FOR_BOT

		double dt = dtime();
		overhead = dt < overhead ? dt : overhead;
	}

	double   t = 0;
	for (int k=0; k < loops; k++) {
		for (int j=0; j < count; j++) {
			data[j*stride] = 0;
		}
		dtime();

		MAIN_FOR_TOP
			_Pragma ("omp atomic")
			data[idx] += 1;
		MAIN_FOR_MID
			data[idx] += 1;
		MAIN_FOR_BOT

		t += dtime();
	}
	opt_hack = ridx;

	if (print_everything) {
		printf("%d,%d,%d,%d,%d,", atomic, random, omp_get_max_threads(), stride, count);
	}

	overhead *= loops;
	/* report nanoseconds per add */
	t = t > overhead ? 1e9*(t - overhead) / (iters * count * loops) : 0;
	printf("%f\n", t);

	return 0;
}

