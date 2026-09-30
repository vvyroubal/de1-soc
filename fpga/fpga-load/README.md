# fpga-load — runtime FPGA reconfiguration from HPS Linux

Design-agnostic tooling to reprogram the DE1-SoC fabric from the running
Debian image (MSEL = 00000), **no JTAG, no reboot**. Works for any
uncompressed `.rbf` — the countdown demo, the GHRD, or your own — **including
designs with HPS-facing slaves on the FPGA bridges**. The `base_fpga_region`
lists the HPS-to-FPGA bridges (`fpga-bridges = <&fpga_bridge0 &fpga_bridge1>`),
so the FPGA-region framework automatically disables the bridges before
reprogramming and re-enables them afterwards — the fabric-side of each bridge
re-synchronises to the new design with no HPS hang. *(Verified on hardware:
both a self-contained design (countdown) and a bridge-using design (the
camstream peripherals at `0xFF20_0000` / `0xC0000000`) load at runtime and
work — camstream's registers read back and its selftest passes after a
runtime load.)*

> **Requires the full runtime-reconfig stack** (all shipped in this image): the
> `dtbocfg` module must load (its vermagic must match the kernel), the kernel
> must have `CONFIG_OF_FPGA_REGION=y` so `base_fpga_region` is a real
> fpga-region, and `fpga-load.sh` must set the overlay's `status` attribute to
> `1` to actually apply it (writing the `dtbo` blob alone only *stores* it).
> All three are in place here; older images missing any one silently fail to
> reprogram (the FPGA manager keeps reporting the previous `operating` state).

| File | Purpose |
|------|---------|
| `fpga-load.sh` | The loader (the image installs it at `/usr/local/sbin/fpga-load.sh`). Applies a *generic* overlay to `/soc/base_fpga_region` naming a bitstream under `/lib/firmware` (by default `fpga.rbf`, where it stages **whatever `.rbf` you pass**), so the FPGA Manager programs the fabric. Builds the overlay on the board with `dtc`; falls back to an embedded compiled copy for `fpga.rbf` on images without `dtc`. |
| `fpga_generic_overlay.dts` | Source of the default overlay (firmware `fpga.rbf`); the script's `overlay_dts` generates the same with any name, and the embedded fallback is this file compiled. |
| `fpga-overlay.service` | Optional systemd unit to re-apply the staged design at boot. |

## Usage

Needs an **uncompressed** `.rbf` (MSEL=00000 / FPP path):
`quartus_cpf -c -o bitstream_compression=off design.sof design.rbf`.

```bash
sudo fpga-load.sh design.rbf           # copy to /lib/firmware/fpga.rbf + program
sudo fpga-load.sh --link design.rbf    # symlink fpga.rbf -> design.rbf + program (no copy)
sudo fpga-load.sh --name designs/x.rbf # program /lib/firmware/designs/x.rbf as-is (needs dtc)
sudo fpga-load.sh --apply              # re-program the staged /lib/firmware/fpga.rbf
cat /sys/class/fpga_manager/fpga0/state   # -> operating
sudo fpga-load.sh -u                   # remove overlay (release region)
sudo fpga-load.sh -s                   # status (applied firmware, staged file, dtc)
```

Which form to use:
- **Plain `<design.rbf>`** copies the file (~7 MB) to `/lib/firmware/fpga.rbf`.
- **`--link`** makes `fpga.rbf` a symlink to your file instead, so switching
  between designs you keep elsewhere costs no copy (the kernel firmware loader
  follows symlinks). Works without `dtc`. The file must stay where it is.
- **`--name <fw>`** loads any file under `/lib/firmware` by name, e.g. a library
  of designs in `/lib/firmware/designs/`, without touching `fpga.rbf`. The name
  is relative to `/lib/firmware` (subdirectories fine; no absolute paths or
  `..`; letters, digits, `. _ + - /`). Needs `dtc` to build the overlay:
  included in images after v2.0.1; on v2.0.1 run
  `sudo apt install device-tree-compiler`.
- `fpga-overlay.service` re-applies `fpga.rbf` at boot, so the plain and
  `--link` forms persist across reboots (with the service enabled); `--name`
  does not.

How it works: mainline has no built-in userspace overlay interface, so the
image autoloads the **`dtbocfg`** module (providing
`/sys/kernel/config/device-tree/overlays`). `fpga-load.sh` writes the overlay
blob to the overlay's `dtbo` attribute **and then writes `1` to its `status`
attribute** — that second write is what makes `dtbocfg` call
`of_overlay_fdt_apply`, which fires the fpga-region notifier and makes the FPGA
Manager program the bitstream (dmesg shows `fpga_manager fpga0: writing …` and
the `fpga_bridge` disable/enable around it).

A design-specific overlay example (naming its own `.rbf` instead of the
generic staged one) is `../countdown/countdown_overlay.dts`; with `dtc` on the
board, `fpga-load.sh --name countdown.rbf` applies the equivalent overlay.
