// B3 — contention_bw: N cores run STREAM-copy on private buffers simultaneously.
// PRIMARY experiment: aggregate bandwidth scaling — NoC expected to WIN.
// Spec: docs/03-spec-benchmarks.md
#include <stdint.h>
#include <stdio.h>
#include "perf.h"
#include "sync.h"

#ifndef NCORES
#define NCORES 4            // set by Makefile: -DNCORES=$(CONFIG_CORES)
#endif
#define BUF_WORDS (2 * 1024 * 1024 / 8)   // 2MB per core
#define ITERS 4

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
  for (int it = 0; it < ITERS; it++)
    for (uint64_t i = 0; i < BUF_WORDS; i++) dst[i] = src[i];
  mem_fence();
  cycles_per_core[hart] = rdcycle() - c0;

  barrier_wait(&bar);
}

int main(void) {
  uint64_t hart = rdhartid();
  if (hart >= NCORES) { while (1) asm volatile("wfi"); }

  if (hart == 0) { barrier_init(&bar, NCORES); __atomic_store_n(&go, 1, __ATOMIC_RELEASE); }
  else while (!__atomic_load_n(&go, __ATOMIC_ACQUIRE)) {}

  stream_copy(hart);

  if (hart == 0) {
    // Aggregate: total bytes moved / max core time (the slowest core bounds the run)
    uint64_t max_c = 0;
    for (int i = 0; i < NCORES; i++) if (cycles_per_core[i] > max_c) max_c = cycles_per_core[i];
    uint64_t total_bytes = (uint64_t)NCORES * ITERS * BUF_WORDS * 8 * 2;  // rd+wr
    REPORT("contention_bw", NCORES, total_bytes, max_c, 0);
    for (int i = 0; i < NCORES; i++)
      printf("percore:%d,%lu\n", i, (unsigned long)cycles_per_core[i]);
  } else {
    while (1) asm volatile("wfi");
  }
  return 0;
}
