// B4 — loaded_latency: core 0 pointer-chase (as B1) while N-1 cores pump
// STREAM-copy background traffic. PRIMARY experiment: crossbar latency climbs
// under load, NoC stays flat; find saturation. Spec: docs/03-spec-benchmarks.md
//
// Sweep N: build one binary per active-loader count, e.g.
//   make DEFS='-DACTIVE_LOADERS=0' ... -DACTIVE_LOADERS=$((NCORES-1))
// REPORT n_active_cores = 1 + ACTIVE_LOADERS (chaser + loaders).
#include <stdint.h>
#include <stdio.h>
#include "perf.h"
#include "sync.h"

#ifndef NCORES
#define NCORES 4
#endif
#ifndef ACTIVE_LOADERS
#define ACTIVE_LOADERS (NCORES - 1)
#endif
#ifndef FOOTPRINT
#define FOOTPRINT (4 * 1024 * 1024)            // chase arena, 4MB > L2
#endif
#ifndef N_LOADS
#define N_LOADS   100000
#endif
#ifndef BUF_WORDS
#define BUF_WORDS (2 * 1024 * 1024 / 8)        // 2MB per loader buffer
#endif
#define STRIDE    256
#define N_NODES   (FOOTPRINT / STRIDE)
#define PARTICIPANTS (1 + ACTIVE_LOADERS)
#define CHECK_EVERY 4096                        // loader polls done flag per chunk

static uint8_t arena[FOOTPRINT] __attribute__((aligned(64)));
static uint64_t idx[N_NODES];                   // static, not stack (P0 lesson #4)
static uint64_t srcbuf[NCORES][BUF_WORDS] __attribute__((aligned(64)));
static uint64_t dstbuf[NCORES][BUF_WORDS] __attribute__((aligned(64)));
static barrier_t bar;
static volatile int go = 0, done = 0;

static uint64_t lcg(uint64_t *s) { *s = *s * 6364136223846793005ULL + 1442695040888963407ULL; return *s >> 33; }

static void loader(uint64_t hart) {              // background STREAM until done
  uint64_t *src = srcbuf[hart], *dst = dstbuf[hart];
  for (uint64_t i = 0; i < BUF_WORDS; i++) src[i] = hart * 1000 + i;  // init + warm
  barrier_wait(&bar);
  while (!__atomic_load_n(&done, __ATOMIC_ACQUIRE)) {
    for (uint64_t i = 0; i < BUF_WORDS; i += CHECK_EVERY) {
      for (uint64_t k = i; k < i + CHECK_EVERY && k < BUF_WORDS; k++) dst[k] = src[k];
      if (__atomic_load_n(&done, __ATOMIC_ACQUIRE)) break;
    }
  }
  barrier_wait(&bar);
}

static void secondary(void) {
  uint64_t hart = rdhartid();
  if (hart > ACTIVE_LOADERS) return;             // loaders are harts 1..ACTIVE_LOADERS
  while (!__atomic_load_n(&go, __ATOMIC_ACQUIRE)) {}
  loader(hart);
}
SECONDARY_ENTRY(secondary)

int main(void) {
  barrier_init(&bar, PARTICIPANTS);
  __atomic_store_n(&go, 1, __ATOMIC_RELEASE);

  // Build pointer chain (same construction as B1, seed 42)
  for (uint64_t i = 0; i < N_NODES; i++) idx[i] = i;
  uint64_t seed = 42;
  for (uint64_t i = N_NODES - 1; i > 0; i--) {
    uint64_t j = lcg(&seed) % i;
    uint64_t t = idx[i]; idx[i] = idx[j]; idx[j] = t;
  }
  for (uint64_t i = 0; i < N_NODES; i++) {
    uint64_t next = idx[(i + 1) % N_NODES];
    *(volatile uint64_t **)(arena + idx[i] * STRIDE) = (uint64_t *)(arena + next * STRIDE);
  }
  volatile uint64_t **p = (volatile uint64_t **)(arena + idx[0] * STRIDE);
  for (int w = 0; w < N_LOADS / 10; w++) p = (volatile uint64_t **)*p;   // warm-up

  barrier_wait(&bar);                            // loaders init done, traffic flowing

  mem_fence();
  uint64_t c0 = rdcycle(), i0 = rdinstret();
  for (int n = 0; n < N_LOADS; n++) p = (volatile uint64_t **)*p;
  mem_fence();
  uint64_t c1 = rdcycle(), i1 = rdinstret();

  __atomic_store_n(&done, 1, __ATOMIC_RELEASE);
  barrier_wait(&bar);

  REPORT("loaded_latency", PARTICIPANTS, N_LOADS, c1 - c0, i1 - i0);
  printf("sink:%p\n", (void *)p);
  return 0;
}
