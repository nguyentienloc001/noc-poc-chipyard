// B5 — core2core: ping-pong via shared memory, round-trip latency for EVERY
// core pair -> NxN matrix in raw log (c2c: lines). On a mesh the matrix shows
// hop-distance structure; on a crossbar it is flat but saturates under
// parallel pairs (all-to-all variant: P2 if needed). Spec: docs/03.
//
// REPORT line = pair (0,1) as the canonical headline (param = N_RT,
// derived = cycles/round-trip). Full matrix: lines "c2c:<i>,<j>,<cycles>".
#include <stdint.h>
#include <stdio.h>
#include "perf.h"
#include "sync.h"

#ifndef NCORES
#define NCORES 4
#endif
#ifndef N_RT
#define N_RT 1000                               // round-trips per pair
#endif

typedef struct {
  volatile uint64_t ping __attribute__((aligned(64)));
  volatile uint64_t pong __attribute__((aligned(64)));
} mbox_t;

static mbox_t mbox __attribute__((aligned(64)));
static barrier_t bar;
static volatile uint64_t rt_cycles[NCORES][NCORES];  // [initiator][responder]
static volatile int go = 0;

static void run_pair(uint64_t hart, int i, int j) {
  if (hart == (uint64_t)i) {                    // initiator: measure
    // warm-up round-trips
    for (uint64_t r = 1; r <= N_RT / 10 + 1; r++) {
      __atomic_store_n(&mbox.ping, r, __ATOMIC_RELEASE);
      while (__atomic_load_n(&mbox.pong, __ATOMIC_ACQUIRE) != r) {}
    }
    uint64_t base = N_RT / 10 + 1;
    mem_fence();
    uint64_t c0 = rdcycle();
    for (uint64_t r = base + 1; r <= base + N_RT; r++) {
      __atomic_store_n(&mbox.ping, r, __ATOMIC_RELEASE);
      while (__atomic_load_n(&mbox.pong, __ATOMIC_ACQUIRE) != r) {}
    }
    mem_fence();
    rt_cycles[i][j] = rdcycle() - c0;
  } else if (hart == (uint64_t)j) {             // responder: echo
    uint64_t last = 0;
    uint64_t total = (N_RT / 10 + 1) + N_RT;
    while (last < total) {
      uint64_t v = __atomic_load_n(&mbox.ping, __ATOMIC_ACQUIRE);
      if (v != last) { last = v; __atomic_store_n(&mbox.pong, v, __ATOMIC_RELEASE); }
    }
  }
}

static void all_pairs(uint64_t hart) {
  for (int i = 0; i < NCORES; i++) {
    for (int j = 0; j < NCORES; j++) {
      if (i == j) continue;
      if (hart == 0) { mbox.ping = 0; mbox.pong = 0; }  // reset between pairs
      barrier_wait(&bar);
      run_pair(hart, i, j);
      barrier_wait(&bar);
    }
  }
}

static void secondary(void) {
  uint64_t hart = rdhartid();
  if (hart >= NCORES) return;
  while (!__atomic_load_n(&go, __ATOMIC_ACQUIRE)) {}
  all_pairs(hart);
}
SECONDARY_ENTRY(secondary)

int main(void) {
  barrier_init(&bar, NCORES);
  __atomic_store_n(&go, 1, __ATOMIC_RELEASE);

  all_pairs(0);

  for (int i = 0; i < NCORES; i++)
    for (int j = 0; j < NCORES; j++)
      if (i != j)
        printf("c2c:%d,%d,%lu\n", i, j, (unsigned long)rt_cycles[i][j]);
  // canonical headline: pair (0,1); derived = cycles/round-trip
  REPORT("core2core", NCORES, N_RT, rt_cycles[0][1], 0);
  return 0;
}
