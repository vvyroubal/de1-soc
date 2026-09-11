# DE1-SoC — HPS Linux + FPGA

Working tree for the **Terasic DE1-SoC** board (Intel Cyclone V SoC, dual-core
ARM Cortex-A9 HPS + FPGA fabric, device `5CSEMA5F31C6`): a modern **Debian 12 /
Linux 6.12** SD-card image, FPGA designs, a bilingual setup manual, and the
build system that produces it all from source.

> New to the board and want pictures? The **illustrated setup manual** is in
> [`manual/`](manual/) (`main_en.pdf` / `main_hr.pdf`). This README is the
> text quick-start + reference.

---

## What you need

**Hardware**
- Terasic DE1-SoC board + its **12 V** power supply (barrel jack).
- A **microSD card**, ≥ 2 GB (the image ships ~1.8 GB and grows to fill the card).
- A **USB cable** for the serial console (the board's UART-to-USB port; it
  enumerates on the host as a Silicon Labs **CP2105**, which presents *two*
  `/dev/ttyUSB*` ports — the HPS console is the **first**, usually `ttyUSB0`).
- Optional: an **Ethernet cable** (for SSH / networking), and a USB cable to the
  **USB-Blaster II** JTAG port if you want to program the FPGA over JTAG.

**Host (to build the image or flash a card)**
- A **Debian/Ubuntu x86-64** machine with `sudo` and an **internet connection**
  (the build fetches the Linux kernel from kernel.org and Debian packages from
  the Debian mirror).
- An SD card reader.

**You do NOT need Quartus** to build or run the OS image — the compiled FPGA
bitstream (`hps/newimage/fpga/soc_system.rbf`) is committed. Quartus is only
needed to *rebuild/modify* the FPGA fabric (see [FPGA](#fpga)).

---

## Quick start

### 1. Get an image
Clone the repo **with submodules** (the Linux kernel source is a shallow
submodule pinned to `v6.12`), then build from source (no Quartus needed):

```bash
git clone --recurse-submodules https://github.com/vvyroubal/de1-soc.git DE1-SoC
cd DE1-SoC/hps/newimage
make deps      # one-time: install host build tools (uses sudo/apt)
make all       # build kernel + Debian rootfs, assemble the image
```

(Cloned without `--recurse-submodules`? No problem — `make` initializes the
kernel submodule for you, or run `git submodule update --init --depth 1`.)

This produces **`hps/newimage/image/de1soc-debian12-6.12.img`** (uncompressed).
Details, internals, and an (optional) prebuilt-release path:
**[`hps/newimage/README.md`](hps/newimage/README.md)**.

### 2. Flash the SD card

Find your card's device node first — **picking the wrong one will destroy your
host disk**:

```bash
lsblk        # identify the card, e.g. /dev/sdX  (NOT a partition like sdX1)
```

Then write the image (replace `/dev/sdX` with your card):

```bash
sudo dd if=hps/newimage/image/de1soc-debian12-6.12.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

### 3. Set up and boot the board
1. **MSEL = `00000`** — set all MSEL switches on the **SW10** DIP block to 0
   (MSEL[4:0] = 00000; see the DE1-SoC manual for the exact switch orientation).
   The HPS/U-Boot configures the FPGA, so **wrong MSEL is the #1 cause of a
   board that won't boot / FPGA not configured.**
2. Insert the flashed microSD card.
3. Connect the **UART-to-USB** port to your PC and open a serial terminal at
   **115200 8N1**:
   ```bash
   screen /dev/ttyUSB0 115200      # or: picocom -b 115200 /dev/ttyUSB0
   ```
   (Your user must be in the `dialout` group: `sudo usermod -aG dialout $USER`,
   then re-login. If nothing appears, try the other CP2105 port, e.g.
   `ttyUSB1`.)
4. Apply **12 V** power.

### 4. First boot
You should see, within a few seconds, the vendor U-Boot, then:

```
u-boot.scr: loading GHRD soc_system.rbf into the FPGA fabric
FPGA configured with soc_system.rbf
...
de1-soc-debian login:
```

Log in as **`debian`** / **`temppwd`** (root password is also `temppwd`).
Full boot to login takes roughly half a minute.

### 5. First-run housekeeping
```bash
sudo /usr/local/sbin/expand-rootfs.sh && sudo reboot   # grow rootfs to fill the card
```

---

## Networking / SSH
`eth0` is configured for **DHCP** and `ssh` is enabled. Plug in Ethernet and:

```bash
ssh debian@de1-soc-debian        # by hostname (mDNS/your DNS), or use the IP
```
Find the IP from your router, or on the serial console with `ip a`.

---

## Repository map

Only the paths below exist in a fresh clone. The Linux kernel source is a
**shallow git submodule** (`hps/newimage/kernel/linux-6.12` @ `v6.12`) —
populated by `--recurse-submodules` or by `make`. Other build outputs (the
Debian rootfs, Quartus `db/`/`output_files/`, `.img` files, the Qsys `de1_soc/`
dir) are **generated, not tracked**, and won't be present until you build.

| Path | What it is |
|---|---|
| **[`hps/newimage/`](hps/newimage/)** | The Debian 12 + Linux 6.12 SD-image build — `Makefile`, scripts, kernel config + DE1-SoC device tree, committed bitstream + vendor bootloader, license bundle. **Start here.** |
| **[`fpga/`](fpga/)** | FPGA designs: [`hps_ghrd/`](fpga/hps_ghrd/) (the HPS reference design → `soc_system.rbf`), [`countdown/`](fpga/countdown/) (standalone 7-seg demo), `minimal/`, the top-level `de1soc_blinker` (`rtl/` + `constraints/` + `build.tcl`/`program.sh`). |
| **[`manual/`](manual/)** | Bilingual (EN/HR) illustrated LaTeX setup manual, with committed PDFs. |
| `BSP/` | Notes for the vendor stock Ubuntu 16.04 image (the image itself is not in the repo — download it from Terasic). |

## Boot chain (shipping image)

BootROM → **vendor U-Boot 2013.01.01** (in the type-A2 partition) → `u-boot.scr`
(loads the FPGA GHRD `soc_system.rbf`, sets root to `/dev/mmcblk0p3`) → **mainline
Linux 6.12** → **Debian 12**. The mainline U-Boot SPL cannot reliably read the SD
on this board, so the proven vendor preloader is used; the rest of the stack is
modern and built from source. SD layout (partition numbers = disk order): `p1`
FAT (boot) · `p2` type-A2 (vendor preloader) · `p3` ext4 rootfs (last, grows).

## FPGA

- **Rebuild / modify the fabric bitstream** (`soc_system.rbf`): needs Quartus —
  see [`fpga/hps_ghrd/README.md`](fpga/hps_ghrd/README.md) for the
  `qsys-generate → compile → quartus_cpf` recipe.
- **Program a standalone design over JTAG**: `cd fpga && quartus_sh -t build.tcl`
  then `./program.sh` (USB-Blaster II).
- **Load a bitstream at runtime from Linux** (no reboot): `sudo fpga-load.sh <uncompressed.rbf>`.
  The image ships `/usr/local/sbin/fpga-load.sh` and autoloads the `dtbocfg`
  overlay module, so the FPGA Manager reprograms the fabric from userspace via a
  device-tree overlay on `/soc/base_fpga_region`. See [`fpga/countdown/`](fpga/countdown/).

## Licensing
Open-source notices and the corresponding-source bundle are in
[`hps/newimage/legal/NOTICE.md`](hps/newimage/legal/NOTICE.md) (and ship on the
device under `/usr/share/doc/de1soc-open-source-licenses/`). GPL source is
provided alongside the binaries; the FPGA bitstream is redistributable
(community GHRD + free Altera HPS IP, attribution only). Project code © VUKA,
licensed **GPL-2.0-or-later** (see [`LICENSE`](LICENSE)).

> Engineering documentation, not legal advice — have counsel review before
> external distribution.

## Troubleshooting

| Symptom | Check |
|---|---|
| **Nothing on the serial console** | MSEL = 00000; baud **115200**; the *other* CP2105 port (`ttyUSB1`); `dialout` group; cable/port. |
| **Board won't boot / no U-Boot** | Re-verify the flash target (`lsblk`), that MSEL = 00000, and reseat the card. |
| **FPGA "not configured"** | MSEL must be **00000** (HPS configures the fabric via FPP). |
| **`journalctl` says "insufficient permissions"** | Fixed in the current image; if seen, `sudo usermod -aG systemd-journal debian` and re-login. |
| **`hostnamectl`: "Failed to connect to bus"** | Fixed (dbus is included); on an old image: `sudo apt install -y dbus`. |
| **Clock is wrong (no RTC)** | It sets over NTP once networked (systemd-timesyncd). |
