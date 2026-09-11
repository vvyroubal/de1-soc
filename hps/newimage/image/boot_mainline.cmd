echo "=== DE1-SoC Debian / mainline U-Boot ==="
if load mmc 0:1 ${loadaddr} soc_system.rbf; then
    fpga load 0 ${loadaddr} ${filesize}
    echo "FPGA configured with soc_system.rbf"
fi
load mmc 0:1 ${kernel_addr_r} zImage
load mmc 0:1 ${fdt_addr_r} socfpga_cyclone5_de1_soc.dtb
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rw rootwait
bootz ${kernel_addr_r} - ${fdt_addr_r}
