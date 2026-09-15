# DE1-SoC GHRD — FPGA fabric for the HPS (generates `soc_system.rbf`)

This is the **Golden Hardware Reference Design**: the FPGA-side system (HPS↔FPGA
bridges + a small probe) whose compiled bitstream is the `soc_system.rbf` loaded
at boot by the Debian image (`hps/newimage/`). The prebuilt bitstream is already
committed at `hps/newimage/fpga/soc_system.rbf`, so **you only need this design
if you want to rebuild or modify the fabric** — the OS image builds and boots
without touching it.

## Requires
Intel **Quartus Prime Lite** (the design was built with 25.1std; a nearby
version is fine) with the Cyclone V device support. No IP license is needed
(only the free `altera_hps` bridge + clocks).

## License / provenance
The top-level HDL (`de1_soc_top*.vhd`) is the community DE1-SoC GHRD by **Sahand
Kashani-Akhavan** ("SoC-FPGA Design Guide",
`https://github.com/sahandKashani/SoC-FPGA-Design-Guide`), released into the
public domain under **The Unlicense** — full text in
[`LICENSE.upstream`](LICENSE.upstream). The Intel/Altera HPS IP pulled in via
Platform Designer is governed by Intel's IP license; the compiled `.rbf` is
redistributable (see `../../hps/newimage/legal/NOTICE.md`).

## Canonical project
`de1_soc_top_v2` is the canonical top — it produced the shipped
`soc_system.rbf`. The other files here (`de1_soc_top`, `_fixed`, `_min`, the
`create_quartus*.tcl`, `compile_staged*.tcl`, `probe2/3/4.qsys`,
`test_probe*.tcl`, `minimize_system.tcl`, …) are **experimental iterations**
kept for reference; ignore them unless you know you need them.

## A clone cannot open this project until you regenerate the Qsys system
`de1_soc_top_v2.qsf` references `de1_soc/synthesis/de1_soc.qip`, but the
Qsys-generated `de1_soc/` directory is **not** in git (it's regenerated output).
Generate it first from `de1_soc.qsys`.

## Rebuild `soc_system.rbf`

```bash
cd fpga/hps_ghrd

# 1) regenerate the Qsys system (creates de1_soc/synthesis/de1_soc.qip)
qsys-generate de1_soc.qsys --synthesis=VERILOG

# 2) compile the canonical project -> output_files_v2/de1_soc_top_v2.sof
quartus_sh --flow compile de1_soc_top_v2

# 3) convert to an UNCOMPRESSED raw bitstream (required for MSEL=00000 / FPP;
#    a compressed .rbf fails to configure in this mode)
quartus_cpf -c -o bitstream_compression=off \
  output_files_v2/de1_soc_top_v2.sof soc_system.rbf

# 4) install it for the OS image build
cp soc_system.rbf ../../hps/newimage/fpga/soc_system.rbf
```

The result should be ~7 MB (uncompressed). A compressed `.rbf` (~2 MB) will
**not** configure the device with MSEL=00000 — always pass
`bitstream_compression=off`.

## Notes
- MSEL must be **00000** on the board (HPS/U-Boot configures the FPGA via FPP).
- To load a bitstream at runtime from Linux instead of at boot, see the
  overlay/configfs approach in `../fpga-load/` (`fpga-load.sh`,
  `fpga_generic_overlay.dts`).
