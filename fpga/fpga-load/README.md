# fpga-load — runtime FPGA reconfiguration from HPS Linux

Design-agnostic tooling to reprogram the DE1-SoC fabric from the running
Debian image (MSEL = 00000), **no JTAG, no reboot**. Works for any
**self-contained** design's uncompressed `.rbf` — the countdown demo or your
own logic that has no HPS-facing interfaces.

> **Scope — self-contained designs only.** Runtime reconfiguration works for
> designs that do **not** talk to the HPS through the FPGA bridges. If your
> design exposes memory-mapped slaves to the HPS (peripherals on the
> lightweight or full HPS-to-FPGA bridge, e.g. addresses `0xFF20_0000` /
> `0xC0000000`), load it **at boot** instead — put its `.rbf` on the FAT boot
> partition as `soc_system.rbf` so U-Boot configures it before Linux. A
> runtime `fpga-manager` reconfiguration swaps the fabric out from under the
> already-initialised bridges, and the fabric-side of the bridge does not
> re-synchronise (verified on hardware: the HPS then hangs on the first access
> to a fabric slave, and no HPS-side bridge-reset toggle recovers it). This is
> a limitation of the runtime reconfiguration path on this SoC, not of a
> particular design.

| File | Purpose |
|------|---------|
| `fpga-load.sh` | The loader (the image installs it at `/usr/local/sbin/fpga-load.sh`). Stages **whatever `.rbf` you pass** to `/lib/firmware/fpga.rbf` and applies an embedded *generic* overlay naming `fpga.rbf`, so the FPGA Manager programs the fabric. |
| `fpga_generic_overlay.dts` | Source of that embedded overlay (target `/soc/base_fpga_region`) — reference / customizing. |
| `fpga-overlay.service` | Optional systemd unit to re-apply the staged design at boot. |

## Usage

Needs an **uncompressed** `.rbf` (MSEL=00000 / FPP path):
`quartus_cpf -c -o bitstream_compression=off design.sof design.rbf`.

```bash
sudo /usr/local/sbin/fpga-load.sh design.rbf   # stage to /lib/firmware + program
cat /sys/class/fpga_manager/fpga0/state        # -> operating
sudo /usr/local/sbin/fpga-load.sh -u           # remove overlay (release region)
sudo /usr/local/sbin/fpga-load.sh -s           # status
```

How it works: mainline has no built-in userspace overlay interface, so the
image autoloads the **`dtbocfg`** module (providing
`/sys/kernel/config/device-tree/overlays`); applying an overlay that targets
`/soc/base_fpga_region` makes the FPGA Manager program the bitstream.
*(Verified on hardware: `state` → `operating`.)*

A design-specific overlay example (naming its own `.rbf` instead of the
generic staged one) is `../countdown/countdown_overlay.dts`.
