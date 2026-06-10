// NoC-PoC: cycle/instret measurement helpers (bare-metal, RV64)
#ifndef NOC_POC_PERF_H
#define NOC_POC_PERF_H

#include <stdint.h>

static inline uint64_t rdcycle(void) {
  uint64_t c;
  asm volatile("rdcycle %0" : "=r"(c));
  return c;
}

static inline uint64_t rdinstret(void) {
  uint64_t i;
  asm volatile("rdinstret %0" : "=r"(i));
  return i;
}

static inline uint64_t rdhartid(void) {
  uint64_t h;
  asm volatile("csrr %0, mhartid" : "=r"(h));
  return h;
}

// Memory fence to delimit measured region
static inline void mem_fence(void) { asm volatile("fence rw, rw" ::: "memory"); }

// Result line format consumed by scripts/parse_results.py:
//   CSV:<bench>,<n_active_cores>,<param>,<cycles>,<instret>
#define REPORT(bench, ncores, param, cycles, instret) \
  printf("CSV:%s,%d,%ld,%lu,%lu\n", (bench), (int)(ncores), (long)(param), \
         (unsigned long)(cycles), (unsigned long)(instret))

#endif
