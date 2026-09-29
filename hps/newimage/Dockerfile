# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# =============================================================================
#  Build container for the DE1-SoC Debian 13 + Linux 6.12 SD image.
#
#  Holds every host tool the build needs (the same set as `make deps`, plus
#  mtools for the loopless assembler). It copies nothing in: the repo is
#  bind-mounted at run time, so the image never goes stale. Normally driven by
#
#     make docker-build        (in hps/newimage/)
#
#  which builds this image (with no build context) and runs the full pipeline
#  inside it. No --privileged is needed: the image is assembled with
#  assemble-image-rootless.sh (no loop devices / mounts). The ONE host
#  prerequisite is qemu-arm registered in binfmt_misc with the F (fix-binary)
#  flag, since binfmt is kernel-global and can't be set up from inside the
#  container — see README.md "Build with Docker".
# =============================================================================
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential bc bison flex libssl-dev kmod cpio xz-utils wget \
      ca-certificates git \
      gcc-arm-linux-gnueabihf \
      debootstrap qemu-user-static \
      u-boot-tools device-tree-compiler \
      dosfstools mtools e2fsprogs fdisk util-linux \
    && rm -rf /var/lib/apt/lists/* \
    # The bind-mounted repo is owned by the host user, not root: without this,
    # git refuses it ("dubious ownership"), `make fetch` can't see the kernel
    # submodule and silently falls back to the tarball.
    && git config --system --add safe.directory '*'

WORKDIR /src/hps/newimage
