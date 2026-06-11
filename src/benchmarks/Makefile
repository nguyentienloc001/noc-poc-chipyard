# NoC-PoC benchmarks — standalone bare-metal build (NO chipyard/tests dependency).
#
# Chipyard 1.13 tests/ uses CMake + htif_nano.specs (needs newlib-nano, absent
# from our picolibc image) -> we link directly against libgloss-htif installed
# in $RISCV during P0. Recipe pinned in phases/P0-environment/report.md.
#
# Usage (inside container):
#   make -C /project/src/benchmarks all NCORES=4
#   make -C /project/src/benchmarks build/zeroload_latency.riscv
#   make ... MARCH=rv64imac MABI=lp64       # small-core configs (needs libgloss
#                                           # rv64imac/lp64 multilib — P2)
#   make ... DEFS='-DFOOTPRINT=2097152 -DN_LOADS=20000'   # smoke params

RISCV  ?= /work/riscv
LIBDIR := $(RISCV)/riscv64-unknown-elf/lib
CC     := riscv64-unknown-elf-gcc

NCORES ?= 4
MARCH  ?= rv64gc
MABI   ?= lp64d
CFLAGS ?= -O2 -Wall
DEFS   ?=

# P0-pinned link recipe: picolibc for libc paths, -B so gcc finds the htif
# specs/ld in $RISCV, htif_wrap routes printf-family straight to HTIF console,
# explicit -T beats the -Tpicolibc.ld that picolibc.specs injects.
LINKSPECS := --specs=picolibc.specs -B$(LIBDIR) \
             --specs=htif.specs --specs=htif_wrap.specs -T$(LIBDIR)/htif.ld

SRCS := $(wildcard src/*.c)
BINS := $(patsubst src/%.c,build/%.riscv,$(SRCS))

.PHONY: all clean help
all: $(BINS)

build/%.riscv: src/%.c common/perf.h common/sync.h | build
	$(CC) $(CFLAGS) -march=$(MARCH) -mabi=$(MABI) -DNCORES=$(NCORES) $(DEFS) \
	  -Icommon $(LINKSPECS) $< -o $@

build:
	mkdir -p build

clean:
	rm -rf build

help:
	@echo "Targets: all (B1-B5 -> build/*.riscv), build/<bench>.riscv, clean"
	@echo "Vars: NCORES($(NCORES)) MARCH($(MARCH)) MABI($(MABI)) DEFS RISCV($(RISCV))"
