# NoC-PoC benchmarks — bare-metal RV64, built against Chipyard's tests infra
#
# Usage (inside chipyard env):
#   make CONFIG_CORES=4 MARCH=rv64gc
#
# Strategy: reuse chipyard/tests/ build infra (crt0, htif syscalls/printf,
# linker script) by dropping our sources there — see 'install' target.
# CHIPYARD_DIR must point to the chipyard checkout.

CHIPYARD_DIR ?= /work/chipyard
CONFIG_CORES ?= 4
MARCH        ?= rv64gc
MABI         ?= lp64d

SRCS := $(wildcard src/*.c)

.PHONY: all install clean help

all: help

help:
	@echo "Targets:"
	@echo "  install  - copy sources+headers into $(CHIPYARD_DIR)/tests and build there"
	@echo "  clean"
	@echo "Vars: CHIPYARD_DIR CONFIG_CORES($(CONFIG_CORES)) MARCH($(MARCH))"

install:
	@test -d $(CHIPYARD_DIR)/tests || (echo "CHIPYARD_DIR invalid: $(CHIPYARD_DIR)"; exit 1)
	cp common/perf.h common/sync.h $(SRCS) $(CHIPYARD_DIR)/tests/
	@echo ">> Sources copied. Add benchmark names to tests/Makefile PROGRAMS, then:"
	@echo ">>   make -C $(CHIPYARD_DIR)/tests CFLAGS_EXTRA='-DNCORES=$(CONFIG_CORES) -march=$(MARCH) -mabi=$(MABI)'"
	@echo ">> (TODO P1: tự động hoá bước này bằng patch tests/Makefile)"

clean:
	rm -f *.riscv *.o
