# DE1-SoC — Debian 12 + Linux 6.12 SD image

A modern OS image for the Terasic DE1-SoC (Intel Cyclone V SoC, `5CSEMA5F31C6`):
Debian 12 (bookworm, armhf) on mainline Linux 6.12, booting via a vendor-hybrid
chain (proven vendor 2013 preloader/U-Boot + mainline kernel + Debian), with the
FPGA GHRD auto-loaded at boot.

**You do not need Quartus** — the compiled FPGA bitstream
(`fpga/soc_system.rbf`) is committed.

For physical board setup (MSEL, serial console, flashing, first boot, SSH) see
the top-level [`../../README.md`](../../README.md). This file covers building the
image.

---

## Build from source

### Prerequisites
A **Debian/Ubuntu x86-64** host with `sudo` and an **internet connection** (the
build fetches the Linux kernel from kernel.org and Debian packages from the
Debian mirror). One command installs the toolchain:

```bash
make deps
```

(Installs: `build-essential`, `debootstrap`, `qemu-user-static`,
`binfmt-support`, `gcc-arm-linux-gnueabihf`, `u-boot-tools`,
`device-tree-compiler`, `dosfstools`, `e2fsprogs`, `util-linux`, `kmod`, `cpio`,
`bc bison flex libssl-dev xz-utils wget`.)

### Build

```bash
make all
```

Runs, in order:
1. **fetch** — initializes the shallow kernel submodule (`kernel/linux-6.12`,
   pinned to the `v6.12` tag). If submodules are unavailable, falls back to a
   pinned, SHA-256-verified tarball from kernel.org (`make fetch-tarball`).
2. **kernel** — applies the custom defconfig (`kernel-custom/socfpga_defconfig`,
   incl. ext4 POSIX ACLs) and the DE1-SoC device tree
   (`kernel-custom/socfpga_cyclone5_de1_soc.dts`, not in mainline), then builds
   `zImage`, dtbs and modules.
3. **dtbocfg** — build the out-of-tree `dtbocfg` overlay-configfs module
   (vendored at `dtbocfg/`) and stage it into the kernel modules tree. This is
   what enables runtime FPGA reconfiguration from Linux (`fpga-load.sh`).
4. **rootfs** — `debootstrap` a bookworm armhf rootfs (incl. `dbus`, ssh, sudo,
   systemd-timesyncd, locales) and configure it (`make-rootfs.sh` →
   `configure-rootfs.sh`). **Needs root** (debootstrap/chroot) — runs via `sudo`.
5. **image** — assemble `image/de1soc-debian12-6.12.img` (`assemble-image.sh`).
   **Needs root** (loopback, mkfs, mount).

Override the privilege escalation with `make ROOT=pkexec all`.
`make clean` removes build outputs; `make distclean` also drops the kernel tarball.

### Flash the result
The build produces an **uncompressed** image. Identify the card with `lsblk`
(wrong target destroys your host disk!), then:

```bash
sudo dd if=image/de1soc-debian12-6.12.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

Then set MSEL = 00000, insert, power on — see the [top-level README](../../README.md).

---

## Prebuilt image (if a release is published)

If a release `.img.xz` is available for this project, you can skip the build and
flash it directly instead of building:

```bash
xzcat de1soc-debian12-6.12.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

(There may be no release yet — in that case, build from source as above.)

---

## What's in the repo vs. fetched/built

| Tracked in git | Generated / built (not in a clone) |
|---|---|
| build scripts, `Makefile`, `make-rootfs.sh` | built kernel (`zImage`, modules) |
| `kernel-custom/` (defconfig + DTS) | Debian `rootfs/`, `modules-staging/` |
| **kernel source** — shallow submodule `kernel/linux-6.12` @ `v6.12` | built `image/*.img` |
| `fpga/soc_system.rbf` (GHRD bitstream) | the Qsys `de1_soc/` dir |
| `fpga/vendor-a2-preloader-uboot.bin` (vendor bootloader) | |
| `image/u-boot.scr` (+ experimental `*mainline*`) | |
| `legal/` incl. `legal/source/*.tar.gz` (GPL corresponding source) | |

## Layout, boot, licensing

- **SD layout** (partition numbers == disk order): `p1` FAT (boot) · `p2`
  type-A2 (vendor preloader) · `p3` ext4 rootfs (last, grows via
  `expand-rootfs.sh`).
- **Boot**: BootROM → vendor U-Boot → `u-boot.scr` (loads `soc_system.rbf`,
  roots `/dev/mmcblk0p3`) → Linux → Debian.
- **Licensing**: see [`legal/NOTICE.md`](legal/NOTICE.md). GPL source ships
  alongside the binaries (§3(a)) — the corresponding U-Boot source is tracked at
  `legal/source/` and installed on-device; the bitstream is redistributable
  (community GHRD + free Altera HPS IP, attribution only).
- `assemble-mainline.sh` is an **experimental** 100%-mainline-SPL variant and is
  **not** the shipping path (the mainline SPL can't read the SD on this board),
  and it needs a separately-built mainline U-Boot tree.
