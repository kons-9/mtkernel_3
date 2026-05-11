################################################################################
# micro T-Kernel 3  —  top-level Makefile
#
# Usage:
#   make BOARD=iote_stm32l4           # use default config
#   make BOARD=iote_stm32l4 CFLAGS="-mcpu=cortex-m4 -Os" LNKFILE=my.ld
################################################################################

BOARD ?= iote_stm32l4

MTKERNEL_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR     ?= $(MTKERNEL_ROOT)/build/$(BOARD)

export MTKERNEL_ROOT BUILD_DIR

# Default goal must be declared before any includes that define targets
.DEFAULT_GOAL := all

# ── Board config (toolchain, BOARD_DIR/CPU_DIR/CORE_DIR) ──────────────────────
include $(MTKERNEL_ROOT)/make/$(BOARD).mk

# ── Generate autoconf.h from Kconfig ─────────────────────────────────────────
AUTOCONF_H := $(BUILD_DIR)/autoconf.h
CONFIG_H   := $(BUILD_DIR)/config.h

$(BUILD_DIR):
	mkdir -p $@

$(AUTOCONF_H): $(MTKERNEL_ROOT)/Kconfig | $(BUILD_DIR)
	@echo 'GEN $@'
	cd $(MTKERNEL_ROOT) && python3 -c \
	  "import kconfiglib; k=kconfiglib.Kconfig('Kconfig'); k.load_allconfig(''); k.write_autoconf('$(AUTOCONF_H)')"

$(CONFIG_H): $(AUTOCONF_H)
	@echo 'GEN $@'
	printf '/* Auto-generated wrapper */\n#include "autoconf.h"\n' > $@

EXE_FILE ?= mtkernel_3
TARGET   ?= $(shell echo $(BOARD) | tr '[:lower:]' '[:upper:]' | sed 's/^/_/;s/$$/_/')
INCPATH  ?= -I"$(MTKERNEL_ROOT)/include" -I"$(MTKERNEL_ROOT)/kernel/knlinc" -I"$(BUILD_DIR)"

export GCC AS LINK CFLAGS ASFLAGS LFLAGS TARGET INCPATH
export BOARD_DIR CPU_DIR CORE_DIR

# ── Collect objects ───────────────────────────────────────────────────────────
OBJS :=

include $(MTKERNEL_ROOT)/kernel/tkernel/Makefile
include $(MTKERNEL_ROOT)/kernel/sysinit/Makefile
include $(MTKERNEL_ROOT)/kernel/inittask/Makefile
include $(MTKERNEL_ROOT)/kernel/tstdlib/Makefile
include $(MTKERNEL_ROOT)/kernel/usermain/Makefile
include $(MTKERNEL_ROOT)/kernel/sysdepend/Makefile

include $(MTKERNEL_ROOT)/lib/libtk/Makefile
include $(MTKERNEL_ROOT)/lib/libtm/Makefile

include $(MTKERNEL_ROOT)/device/Makefile

# ── Dependency files ──────────────────────────────────────────────────────────
DEPS := $(OBJS:.o=.d)
-include $(DEPS)

# All object files depend on autoconf.h
$(OBJS): $(AUTOCONF_H)

# ── Link ──────────────────────────────────────────────────────────────────────
ELF := $(BUILD_DIR)/$(EXE_FILE).elf
MAP := $(BUILD_DIR)/$(EXE_FILE).map

all: $(CONFIG_H) $(ELF)
	@echo 'Build complete: $(ELF)'

$(ELF): $(OBJS) | $(BUILD_DIR)
	@echo 'LINK $@'
	$(LINK) $(LFLAGS) -T $(LNKFILE) -Wl,-Map,"$(MAP)" -o "$@" $(OBJS)

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
