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


#define VARTYPE int
#define LOOPCOUNT 10


#define SETZERO(data)                \
	for (int _SZ_i=0; _SZ_i < vars; _SZ_i++) \
		data[_SZ_i*stride] = 0;

#define INCREMENT(data)              \
	for (int _INC_i=0; _INC_i < vars; _INC_i++) \
		data[_INC_i*stride] += 1;

VARTYPE get_error(VARTYPE *data, int64_t iters, int64_t vars, int64_t stride) {
	VARTYPE err = 0;
	for (int64_t i=0; i < vars; i++)
		err += iters - data[i*stride];
	return err;
}


int main(int argc, char **argv) {
	int64_t iters = 10000;
	int64_t vars = 10;
	int64_t stride = 1;
	size_t data_sz;
	VARTYPE *data;
	double err = 0;
	double t = 0;
	double norm;

	if (argc > 1)
		iters = atoll(argv[1]);
	if (argc > 2)
		vars = atoll(argv[2]);
	if (argc > 3)
		stride = atoll(argv[3]);
	
	data_sz = sizeof(VARTYPE) * vars * stride;
	data = malloc(data_sz);

	for (int k=0; k < LOOPCOUNT; k++) {
		for (int j=0; j < vars; j++) {
			data[j*stride] = 0;
		}
		dtime();
		#pragma omp parallel for
		for (int j=0; j < iters; j++) {
			for (int i=0; i < vars; i++) {
				#ifdef ATOMIC
				#pragma omp atomic
				#endif
				data[i*stride] += 1;
			}
		}
		t += dtime();
		err += get_error(data, iters, vars, stride);
	}
	/* report nanoseconds per add & avg err per thousand adds */
	norm = 1.0 / (iters*vars*LOOPCOUNT);
	printf("%f,%f\n", 1e9*t*norm, 1e3*(double)err*norm /*, data_sz / 1024. */);

	return 0;
}

