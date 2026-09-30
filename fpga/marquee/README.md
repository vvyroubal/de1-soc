# DE1-SoC Marquee (scrolling text)

Standalone FPGA design — **no HPS/Linux involved**. Scrolls an arbitrary text
string right-to-left across the six 7-segment displays, like a marquee sign:

```
HEX5  HEX4  HEX3  HEX2  HEX1  HEX0     <- window slides left over the message
 d     e     b     i     a     n   ...
```

- **Message:** the `MESSAGE` generic in `marquee_top.vhd` (default `"debian 13"`).
  Edit that string to display any text.
- **Speed:** one character every `STEP_MS` ms (default 300 → ~3.3 chars/sec).
- **KEY0** (push button) restarts the scroll from the beginning.

## Font and character support

Each character is decoded by the `glyph()` 7-segment font (bit 0 = segment a …
bit 6 = segment g, active low). It covers the digits `0-9`, a practical
alphabet, and `-` / `_` / space:

- **Clean glyphs:** `0-9`, `A a b C c d E e F G H h J L n o P q r S t U u y`.
- **Case is forced by geometry** — e.g. `b`, `d`, `n`, `o`, `r`, `u` only read
  correctly in lowercase, so both cases map to the legible form.
- **Ambiguous:** `I`/`l` render as a bare vertical bar (like `1`); `i` is a
  single segment. Seven segments cannot form these unambiguously.
- **Unsupported** (`K M V W X Z`, etc.) display **blank** — a 14-/16-segment
  display is needed for those.

The message is padded with one blank screen (6 columns) on each side, so it
scrolls fully in from the right and clears off the left before repeating.

## Build

**GUI:** open `marquee.qpf` in Quartus Prime → *Processing → Start Compilation*.

**Command line:**
```bash
cd fpga/marquee
quartus_sh --flow compile marquee
# output: output_files/marquee.sof
```

To scroll a different message without editing the file, override the generic:
```bash
quartus_map marquee --optimize=balanced \
  --vhdl_generic="MESSAGE=hello 42"     # then quartus_fit / quartus_asm, or just recompile
```
(Editing the `MESSAGE` default in `marquee_top.vhd` is usually simpler.)

## Run it (JTAG — temporary, survives until power-off)

Program the FPGA over the USB-Blaster II. On a standard DE1-SoC chain the Cyclone
V is at index **`@1`** — confirm with `jtagconfig` first, since it can differ:

```bash
jtagconfig
quartus_pgm -m jtag -o "P;output_files/marquee.sof@1"
```

Volatile RAM configuration; works regardless of MSEL and won't disturb an SD /
Linux setup. (If a Linux SD card is inserted, U-Boot reconfigures the fabric with
`soc_system.rbf` at boot and overwrites this — re-run the command after boot, or
use the runtime path below.)

## Run it from HPS Linux at runtime (no JTAG, no reboot)

On the Debian image (MSEL = 00000) reconfigure the fabric from Linux via the
shared loader in [`../fpga-load/`](../fpga-load/). **The image ships it
prebuilt** (v2.0.2+, with the default `"debian 13"` message) at
`/lib/firmware/designs/marquee.rbf`:

```bash
sudo fpga-load.sh --name designs/marquee.rbf        # program the shipped copy
cat /sys/class/fpga_manager/fpga0/state             # -> operating
sudo fpga-load.sh -u                                # remove overlay (release the region)
```

For your own message, rebuild, make an **uncompressed** `.rbf` (MSEL=00000 /
FPP path) and pass it to the loader:

```bash
quartus_cpf -c -o bitstream_compression=off output_files/marquee.sof marquee.rbf
sudo fpga-load.sh marquee.rbf                       # copy to /lib/firmware/fpga.rbf + program
```

After changing the design, refresh the copy the image ships with
`cp marquee.rbf ../../hps/newimage/fpga/designs/` and rebuild the image.

The one marquee-specific file here:
- `marquee_overlay.dts` — overlay source (target `/soc/base_fpga_region`) naming
  `marquee.rbf`, for reference. `fpga-load.sh` generates the same overlay
  itself: copy the bitstream to `/lib/firmware/marquee.rbf` and run
  `sudo fpga-load.sh --name marquee.rbf` (needs `dtc`, preinstalled from v2.0.2).

## Files
| File | Purpose |
|------|---------|
| `marquee_top.vhd` | The design (scroll engine + 7-segment font). |
| `marquee.qsf` | Quartus device (`5CSEMA5F31C6`) + pin assignments. |
| `marquee.qpf` | Quartus project file. |
| `marquee.sdc` | Timing constraint: the 50 MHz `CLOCK_50`. |
| `marquee_overlay.dts` | Marquee-specific overlay source (reference — see above). |
