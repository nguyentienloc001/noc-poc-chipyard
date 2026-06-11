// B3 — contention_bw: N cores run STREAM-copy on private buffers simultaneously.
// PRIMARY experiment: aggregate bandwidth scaling — NoC expected to WIN.
// Spec: docs/03-spec-benchmarks.md
//
// Multi-hart: hart 0 runs main(); harts 1..NCORES-1 enter via SECONDARY_ENTRY
// (libgloss __main contract — see common/sync.h and P1 actual.md 2026-06-11).
#include <stdint.h>
#include <stdio.h>
#include "perf.h"
#include "sync.h"

#ifndef NCORES
#define NCORES 4            // MUST match the simulated config's core count
#endif
#ifndef BUF_WORDS
#define BUF_WORDS (2 * 1024 * 1024 / 8)   // 2MB per core (docs/03 §3)
#endif
#ifndef ITERS
#define ITERS 4
#endif

static uint64_t srcbuf[NCORES][BUF_WORDS] __attribute__((aligned(64)));
static uint64_t dstbuf[NCORES][BUF_WORDS] __attribute__((aligned(64)));
static barrier_t bar;
static volatile uint64_t cycles_per_core[NCORES];
static volatile int go = 0;

static void stream_copy(uint64_t hart) {
  uint64_t *src = srcbuf[hart], *dst = dstbuf[hart];
  for (uint64_t i = 0; i < BUF_WORDS; i++) src[i] = hart * 1000 + i;  // init + warm
  barrier_wait(&bar);

  mem_fence();
  uint64_t c0 = rdcycle();
  for (int it = 0; it < ITERS; it++) {
    for (uint64_t i = 0; i < BUF_WORDS; i++) dst[i] = src[i];
    __asm__ __volatile__("" ::: "memory");   // stop gcc eliding repeated passes
  }
  mem_fence();
  cycles_per_core[hart] = rdcycle() - c0;

  barrier_wait(&bar);
}

static void secondary(void) {
  uint64_t hart = rdhartid();
  if (hart >= NCORES) return;                       // park extra harts
  while (!__atomic_load_n(&go, __ATOMIC_ACQUIRE)) {}
  stream_copy(hart);
}
SECONDARY_ENTRY(secondary)

int main(void) {
  barrier_init(&bar, NCORES);
  __atomic_store_n(&go, 1, __ATOMIC_RELEASE);

  uint64_t i0 = rdinstret();
  stream_copy(0);
  uint64_t i1 = rdinstret();

  // Aggregate: total bytes moved / max core time (the slowest core bounds the run)
  uint64_t max_c = 0;
  for (int i = 0; i < NCORES; i++) if (cycles_per_core[i] > max_c) max_c = cycles_per_core[i];
  uint64_t total_bytes = (uint64_t)NCORES * ITERS * BUF_WORDS * 8 * 2;  // rd+wr
  REPORT("contention_bw", NCORES, total_bytes, max_c, i1 - i0);  // instret = hart 0 sanity
  for (int i = 0; i < NCORES; i++)
    printf("percore:%d,%lu\n", i, (unsigned long)cycles_per_core[i]);
  return 0;
}
