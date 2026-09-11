# Sourced by the vendor U-Boot via `callscript` (runs BEFORE `mmcload; mmcboot`).
# 1) Point the rootfs at p3 (new in-disk-order layout: p1 FAT, p2 A2, p3 rootfs).
#    The vendor env's `mmcboot` uses root=${mmcroot}, so overriding it here wins.
setenv mmcroot /dev/mmcblk0p3
# 2) Configure the FPGA fabric with the GHRD bitstream (needs MSEL=00000).
echo "u-boot.scr: loading GHRD soc_system.rbf into the FPGA fabric"
if fatload mmc 0:1 ${loadaddr} soc_system.rbf; then
    fpga load 0 ${loadaddr} ${filesize}
    echo "FPGA configured with soc_system.rbf"
fi
