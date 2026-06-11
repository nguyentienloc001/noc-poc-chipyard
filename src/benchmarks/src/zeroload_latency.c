// B1 — zeroload_latency: single-core pointer-chase, load-to-use latency to DRAM.
// Expected: NoC LOSES here (router hops add latency). Reported as trade-off.
// Spec: docs/03-spec-benchmarks.md
#include <stdint.h>
#include <stdio.h>
#include "perf.h"

// Defaults per docs/03 spec; overridable with -D for pipeline smoke tests (P0 step 7)
#ifndef FOOTPRINT
#define FOOTPRINT (4 * 1024 * 1024)            // 4MB > L2 512KB
#endif
#ifndef N_LOADS
#define N_LOADS   100000                        // measured loads (Verilator-friendly)
#endif
#define STRIDE    256                           // > cache line (64B), beats prefetcher
#define N_NODES   (FOOTPRINT / STRIDE)

static uint8_t arena[FOOTPRINT] __attribute__((aligned(64)));
// static, NOT stack: 4MB/256*8 = 128KB > htif.ld 24K min stack (P0 report lesson #4)
static uint64_t idx[N_NODES];

// Build a random-permutation cycle of pointers (Sattolo). LCG for determinism.
static uint64_t lcg(uint64_t *s) { *s = *s * 6364136223846793005ULL + 1442695040888963407ULL; return *s >> 33; }

int main(void) {
  if (rdhartid() != 0) { while (1) asm volatile("wfi"); }  // single-core bench

  for (uint64_t i = 0; i < N_NODES; i++) idx[i] = i;
  uint64_t seed = 42;
  for (uint64_t i = N_NODES - 1; i > 0; i--) {           // Sattolo shuffle → one cycle
    uint64_t j = lcg(&seed) % i;
    uint64_t t = idx[i]; idx[i] = idx[j]; idx[j] = t;
  }
  for (uint64_t i = 0; i < N_NODES; i++) {
    uint64_t next = idx[(i + 1) % N_NODES];
    *(volatile uint64_t **)(arena + idx[i] * STRIDE) = (uint64_t *)(arena + next * STRIDE);
  }

  volatile uint64_t **p = (volatile uint64_t **)(arena + idx[0] * STRIDE);

  for (int w = 0; w < N_LOADS / 10; w++) p = (volatile uint64_t **)*p;   // warm-up

  mem_fence();
  uint64_t c0 = rdcycle(), i0 = rdinstret();
  for (int n = 0; n < N_LOADS; n++) p = (volatile uint64_t **)*p;
  mem_fence();
  uint64_t c1 = rdcycle(), i1 = rdinstret();

  // param = N_LOADS; derived metric (cycles/load) computed by parser
  REPORT("zeroload_latency", 1, N_LOADS, c1 - c0, i1 - i0);
  printf("sink:%p\n", (void *)p);               // keep chain alive
  return 0;
}
