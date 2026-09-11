# Contributing

Thanks for your interest in improving the DE1-SoC HPS Linux + FPGA project.

## License of contributions
This project's own code is licensed **GPL-2.0-or-later** (see [`LICENSE`](LICENSE)).
By submitting a contribution you agree it is provided under that license. Add an
SPDX header to new source files:

```
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) <year> <your name>
```

(Use `--` for VHDL, `//` for Verilog/C, `#` for shell/Make/Tcl.) Do **not**
change the license of third-party files (the community GHRD under
`fpga/hps_ghrd/`, the vendor bootloader, or the kernel submodule) — see
`hps/newimage/legal/NOTICE.md`.

## Building
See [`README.md`](README.md) and [`hps/newimage/README.md`](hps/newimage/README.md).
In short, on a Debian/Ubuntu x86-64 host:

```bash
git clone --recurse-submodules <your-fork-url> DE1-SoC
cd DE1-SoC/hps/newimage
make deps
make all
```

The kernel is a shallow submodule pinned to `v6.12`; `make` initializes it if you
didn't clone with `--recurse-submodules`.

## Testing changes
There is no CI for the full image build (it needs root for `debootstrap`/loopback
and is heavy). Please test locally and say what you verified in the PR:

- **Build**: `make all` completes and produces `image/de1soc-debian12-6.12.img`.
- **Boot** (for changes that affect the running system): flash a card, set
  **MSEL = 00000**, boot, and confirm login over serial (`115200 8N1`) and, where
  relevant, SSH. Note the board has no RTC (time sets via NTP once networked).
- **Scripts**: keep them shell-clean (`shellcheck` is a good habit); the build
  scripts must remain path-independent (they resolve their own location).
- **FPGA** (`fpga/`): note whether a design compiles from a clean checkout and,
  for the GHRD, whether the Qsys system regenerates (`fpga/hps_ghrd/README.md`).

## Pull requests
- One logical change per PR; describe **what** and **why**, and what you tested.
- Keep large binaries out of git (the `.gitignore` already excludes build trees,
  images, and Quartus outputs). The only committed binaries are the essential
  inputs: the vendor bootloader, `soc_system.rbf`, and the GPL source tarball.
- Match the surrounding code style and keep documentation (READMEs, the manual)
  in sync with behavior changes.

## Reporting bugs
Open a GitHub issue with your host OS, the board revision, the exact command, and
the relevant serial-console output.
