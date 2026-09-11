# DE1-SoC Countdown (100 → 0)

Standalone FPGA design — **no HPS/Linux involved**. Counts down from 100 to 0 at
1 count per second, wraps back to 100, and repeats. The value is shown in decimal
on the three right-hand 7-segment displays:

```
HEX5  HEX4  HEX3   HEX2  HEX1  HEX0
 —     —     —      H     T     U      (leading zeros blanked)
```

- **KEY0** (push button) resets the count to 100.
- Rate is set by `TICK_MAX` in `countdown_top.vhd` (default = 50,000,000 − 1 → 1 Hz).

## Files
| File | Purpose |
|------|---------|
| `countdown_top.vhd` | The design (counter + BCD + 7-seg decoder). |
| `countdown.qsf` | Quartus device (`5CSEMA5F31C6`) + pin assignments. |
| `countdown.qpf` | Quartus project file. |
| `fpga-load.sh`, `*_overlay.dts`, `fpga-overlay.service` | Load the design at **runtime from HPS Linux** (configfs overlay via `dtbocfg`) — see below. |

## Build

**GUI:** open `countdown.qpf` in Quartus Prime → *Processing → Start Compilation*.

**Command line:**
```bash
cd fpga/countdown
quartus_sh --flow compile countdown
# output: output_files/countdown.sof
```

## Run it (JTAG — temporary, survives until power-off)

Program the FPGA over the USB-Blaster II. On a standard DE1-SoC chain the Cyclone
V is the single programmable device at index **`@1`** (as `../program.sh` uses) —
but always confirm the index for your board with `jtagconfig` first, since it can
differ:

```bash
jtagconfig                                          # list devices + their index
quartus_pgm -m jtag -o "P;output_files/countdown.sof@1"
```

This is volatile RAM configuration and works regardless of the MSEL switch, so it
won't disturb your SD/Linux setup.

> **Note:** if a Linux SD card is inserted, U-Boot reconfigures the FPGA with
> `soc_system.rbf` during boot and will overwrite this design. To see the
> countdown, either remove the SD card, or re-run the `quartus_pgm` command
> *after* the board has booted.

## Run it from HPS Linux at runtime (no JTAG, no reboot)

On the Debian image (MSEL = 00000) you can reconfigure the fabric from Linux.
Mainline has no built-in userspace overlay interface, so the image autoloads the
**`dtbocfg`** module (which provides `/sys/kernel/config/device-tree/overlays`)
and ships **`/usr/local/sbin/fpga-load.sh`**. Applying an overlay that targets
`/soc/base_fpga_region` makes the FPGA Manager program the bitstream. *(Verified
on hardware: `state` → `operating`.)*

Needs an **uncompressed** `.rbf` (MSEL=00000 / FPP path):
`quartus_cpf -c -o bitstream_compression=off countdown.sof countdown.rbf`.

```bash
sudo /usr/local/sbin/fpga-load.sh countdown.rbf     # stage to /lib/firmware + program
cat /sys/class/fpga_manager/fpga0/state             # -> operating
sudo /usr/local/sbin/fpga-load.sh -u                # remove overlay (release the region)
```

Files here:
- `fpga-load.sh` — the loader (installed on the image). It stages **whatever
  `.rbf` you pass** to `/lib/firmware/fpga.rbf` and applies an embedded *generic*
  overlay that names `fpga.rbf` — so the filename you pass is just the source;
  the in-fabric firmware name is always `fpga.rbf`.
- `fpga_generic_overlay.dts` / `countdown_overlay.dts` — overlay sources (target
  `/soc/base_fpga_region`) for reference / customizing. Note
  `countdown_overlay.dts` names `countdown.rbf`; it is **not** what `fpga-load.sh`
  applies — use it only if you apply an overlay manually (then place the bitstream
  at `/lib/firmware/countdown.rbf`).
- `fpga-overlay.service` — optional systemd unit to apply a design at boot.

(Alternatively, put the `.rbf` on the FAT boot partition and load it from
`u-boot.scr` at boot — that's how the GHRD `soc_system.rbf` is loaded.)

## Make it permanent (optional)

To have the design load from the on-board configuration flash at power-up, convert
the `.sof` to a `.jic` for the EPCQ and program it — but that overwrites whatever
FPGA image the flash currently holds, and requires the MSEL switch to be set for
Active Serial boot rather than the `00000` used for the Linux SD flow.
