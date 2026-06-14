// B2 — stream_bw: single-core STREAM (copy/scale/add/triad), buffers > L2.
// Metric: bytes/cycle of ONE core with no contention (upper bound reference
// for B3 scaling). Spec: docs/03-spec-benchmarks.md
//
// REPORT line = triad (canonical STREAM figure). copy/scale/add go to the raw
// log as info: lines — P4 scripts may use them, parser only takes CSV:.
#include <stdint.h>
#include <stdio.h>
#include "perf.h"

#ifndef BUF_WORDS
#define BUF_WORDS (1 * 1024 * 1024 / 8)        // 1MB per array (docs/03 §3; 2MB
                                               // was 350' CI timeout — changes.md
                                               // 2026-06-14; 3MB ws still > L2)
#endif
#ifndef ITERS
#define ITERS 4
#endif

static uint64_t a[BUF_WORDS] __attribute__((aligned(64)));
static uint64_t b[BUF_WORDS] __attribute__((aligned(64)));
static uint64_t c[BUF_WORDS] __attribute__((aligned(64)));

// Compiler barrier between iterations: without it gcc -O2 elides repeated
// idempotent passes (observed on spike: copy ran 1 of 2 ITERS) -> byte count
// would overstate bytes/cycle.
#define KERNEL(stmt) ({                                          \
  mem_fence();                                                   \
  uint64_t c0_ = rdcycle();                                      \
  for (int it_ = 0; it_ < ITERS; it_++) {                        \
    for (uint64_t i = 0; i < BUF_WORDS; i++) { stmt; }           \
    __asm__ __volatile__("" ::: "memory");                       \
  }                                                              \
  mem_fence();                                                   \
  rdcycle() - c0_;                                               \
})

int main(void) {
  if (rdhartid() != 0) { while (1) asm volatile("wfi"); }  // single-core bench

  const uint64_t s = 3;
  for (uint64_t i = 0; i < BUF_WORDS; i++) { a[i] = i; b[i] = 2 * i; c[i] = 3 * i; }  // init + warm

  uint64_t copy_c  = KERNEL(c[i] = a[i]);                  // 2 accesses/elem
  uint64_t scale_c = KERNEL(b[i] = s * c[i]);              // 2
  uint64_t add_c   = KERNEL(c[i] = a[i] + b[i]);           // 3
  uint64_t i0 = rdinstret();
  uint64_t triad_c = KERNEL(a[i] = b[i] + s * c[i]);       // 3
  uint64_t i1 = rdinstret();

  uint64_t w = (uint64_t)ITERS * BUF_WORDS * 8;            // bytes per access-slot
  printf("info:stream_copy,%lu,%lu\n",  (unsigned long)(2 * w), (unsigned long)copy_c);
  printf("info:stream_scale,%lu,%lu\n", (unsigned long)(2 * w), (unsigned long)scale_c);
  printf("info:stream_add,%lu,%lu\n",   (unsigned long)(3 * w), (unsigned long)add_c);
  // param = total bytes of triad; derived = bytes/cycle (parser)
  REPORT("stream_bw", 1, 3 * w, triad_c, i1 - i0);
  printf("sink:%lu\n", (unsigned long)(a[1] + b[2] + c[3]));
  return 0;
}
