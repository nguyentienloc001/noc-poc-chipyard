// NoC-PoC: multi-core synchronization primitives (bare-metal, RV64, AMO-based)
#ifndef NOC_POC_SYNC_H
#define NOC_POC_SYNC_H

#include <stdint.h>

// --- Secondary hart entry (libgloss-htif contract, crtmain.S) ---
// Boot hart enters main(); every other hart waits at __boot_sync then calls
// __main() — which is a weak wfi-loop in libgloss misc/main.c. Multi-hart
// benchmarks MUST override it. fn() runs on each secondary hart (read hartid
// via rdhartid() from perf.h); on return the hart parks so hart 0's exit()
// terminates the simulation cleanly.
#define SECONDARY_ENTRY(fn)                                       \
  void __main(void);                                              \
  void __main(void) {                                             \
    fn();                                                         \
    for (;;) __asm__ __volatile__("wfi");                         \
  }

// Sense-reversing centralized barrier.
// NOTE: the barrier itself goes through the interconnect — keep it OUT of
// measured regions (use it only to align start/end of phases).
typedef struct {
  volatile uint64_t count;
  volatile uint64_t sense;
  uint64_t n_cores;
} barrier_t;

static inline void barrier_init(barrier_t *b, uint64_t n) {
  b->count = 0; b->sense = 0; b->n_cores = n;
}

static inline void barrier_wait(barrier_t *b) {
  uint64_t local_sense = !b->sense;
  uint64_t arrived = __atomic_add_fetch(&b->count, 1, __ATOMIC_ACQ_REL);
  if (arrived == b->n_cores) {
    b->count = 0;
    __atomic_store_n(&b->sense, local_sense, __ATOMIC_RELEASE);
  } else {
    while (__atomic_load_n(&b->sense, __ATOMIC_ACQUIRE) != local_sense) {}
  }
}

#endif
