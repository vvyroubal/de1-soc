# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# =============================================================================
#  DE1-SoC Debian 12 + Linux 6.12 SD-card image — reproducible build
#
#  Quick start (fresh clone):
#     make deps       # one-time: install host build tools (uses sudo/apt)
#     make all        # fetch kernel, build kernel+rootfs, assemble the image
#     # then flash image/de1soc-debian12-6.12.img to an SD card.
#
#  Targets: deps fetch fetch-tarball kernel dtbocfg rootfs image all clean distclean
#  rootfs/ and image assembly need root — they run via $(ROOT) (sudo by default;
#  override with `make ROOT=pkexec image`).
# =============================================================================
SHELL := /bin/bash
HERE  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

KVER    := 6.12
KDIR    := $(HERE)/kernel/linux-$(KVER)
REPO    := $(shell git -C $(HERE) rev-parse --show-toplevel 2>/dev/null)
SUBREL  := hps/newimage/kernel/linux-$(KVER)
# Kernel source is a shallow git submodule pinned to the v$(KVER) tag; these are
# the fallback if submodules are unavailable (see the `fetch` target).
KTAR    := $(HERE)/kernel/linux-$(KVER).tar.xz
KURL    := https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(KVER).tar.xz
KSHA256 := b1a2562be56e42afb3f8489d4c2a7ac472ac23098f1ef1c1e40da601f54625eb
CROSS   := arm-linux-gnueabihf-
DTSDIR  := $(KDIR)/arch/arm/boot/dts/intel/socfpga
JOBS    := $(shell nproc)
ROOT    ?= sudo

.PHONY: all deps fetch fetch-tarball kernel dtbocfg rootfs image clean distclean
all: image

## install the host build tools
deps:
	$(ROOT) apt-get update
	$(ROOT) apt-get install -y build-essential debootstrap qemu-user-static \
	  binfmt-support gcc-arm-linux-gnueabihf bc bison flex libssl-dev \
	  u-boot-tools device-tree-compiler dosfstools e2fsprogs util-linux \
	  kmod cpio xz-utils wget

## fetch kernel source: init the shallow submodule pinned to the v$(KVER) tag.
## A `git clone --recurse-submodules` already populated it; this also restores it
## after `make clean`. Falls back to the pinned tarball if submodules aren't
## available (e.g. a plain tarball export of this repo).
fetch: $(KDIR)/Makefile
$(KDIR)/Makefile:
	@if [ -n "$(REPO)" ] && git -C "$(REPO)" submodule status -- "$(SUBREL)" >/dev/null 2>&1; then \
	  echo "[*] kernel: init shallow submodule (pinned v$(KVER))"; \
	  git -C "$(REPO)" submodule update --init --depth 1 -- "$(SUBREL)"; \
	else \
	  echo "[*] kernel: no submodule -> pinned tarball"; $(MAKE) fetch-tarball; \
	fi

## fallback: download + checksum-verify + extract the pinned tarball
fetch-tarball: $(KTAR)
	echo "$(KSHA256)  $(KTAR)" | sha256sum -c -
	tar -C $(HERE)/kernel -xf $(KTAR)
$(KTAR):
	mkdir -p $(dir $@)
	wget -O $@ "$(KURL)"

## build zImage + dtb + modules (applies the custom defconfig + DE1-SoC DTS)
kernel: fetch
	cp $(HERE)/kernel-custom/socfpga_defconfig $(KDIR)/arch/arm/configs/
	cp $(HERE)/kernel-custom/socfpga_cyclone5_de1_soc.dts $(DTSDIR)/
	grep -q 'socfpga_cyclone5_de1_soc.dtb' $(DTSDIR)/Makefile || \
	  echo 'dtb-$$(CONFIG_ARCH_INTEL_SOCFPGA) += socfpga_cyclone5_de1_soc.dtb' >> $(DTSDIR)/Makefile
	$(MAKE) -C $(KDIR) ARCH=arm CROSS_COMPILE=$(CROSS) socfpga_defconfig
	# Pin a clean "6.12.0" version. The build modifies the pinned submodule tree
	# (DTS/config copied in), which would otherwise stamp "-dirty": disable
	# LOCALVERSION_AUTO (it's `default y`, so the defconfig alone doesn't) AND pass
	# LOCALVERSION= (set-but-empty) so setlocalversion appends no scm/dirty suffix.
	# An empty .scmversion makes setlocalversion skip git detection entirely, so
	# the SAME clean "6.12.0" stamps into the kernel AND every out-of-tree module
	# (e.g. dtbocfg). Without it the module gets "6.12.0-dirty" vermagic and won't
	# load against the clean kernel (modprobe version-magic mismatch), which
	# silently breaks fpga-load.sh runtime reconfiguration.
	: > $(KDIR)/.scmversion
	$(KDIR)/scripts/config --file $(KDIR)/.config --disable LOCALVERSION_AUTO
	$(MAKE) -C $(KDIR) ARCH=arm CROSS_COMPILE=$(CROSS) olddefconfig
	$(MAKE) -C $(KDIR) ARCH=arm CROSS_COMPILE=$(CROSS) LOCALVERSION= -j$(JOBS) zImage modules dtbs
	rm -rf $(HERE)/modules-staging
	$(MAKE) -C $(KDIR) ARCH=arm CROSS_COMPILE=$(CROSS) LOCALVERSION= \
	  INSTALL_MOD_PATH=$(HERE)/modules-staging modules_install

## build the dtbocfg overlay-configfs module and stage it with the kernel modules
## (gives userspace a way to apply device-tree overlays -> runtime FPGA reconfig)
dtbocfg: kernel
	$(MAKE) -C $(HERE)/dtbocfg ARCH=arm CROSS_COMPILE=$(CROSS) KERNEL_SRC=$(KDIR) all
	install -D -m 0644 $(HERE)/dtbocfg/dtbocfg.ko \
	  $(HERE)/modules-staging/lib/modules/$$(cat $(KDIR)/include/config/kernel.release)/extra/dtbocfg.ko

## debootstrap + configure the Debian rootfs (needs root; uses staged modules)
rootfs: dtbocfg
	$(ROOT) bash $(HERE)/make-rootfs.sh

## assemble the SD image (needs root: loopback, mkfs, mount)
image: rootfs
	$(ROOT) bash $(HERE)/assemble-image.sh

## remove build outputs (keeps the downloaded kernel tarball)
clean:
	$(ROOT) rm -rf $(HERE)/rootfs $(HERE)/modules-staging
	rm -rf $(KDIR) $(HERE)/image/*.img

## also remove the downloaded kernel tarball
distclean: clean
	rm -f $(KTAR)
