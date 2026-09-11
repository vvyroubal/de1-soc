NOTE (this repo): the stock vendor image itself is NOT included here (it is large
and gitignored). Download it from Terasic's DE1-SoC resources / System CD. The
text below is Terasic's original setup note for that image, kept for reference.
For the modern Debian 12 / Linux 6.12 image built by this repo, see ../README.md.
----------------------------------------------------------------------------------

Prerequisite: you need at least a 8Gb microSD card

Setup steps:
1. Unzip the image file
2. Insert the microSD card to the host PC and write the image file into the microSD with the Win32DiskImager tool
3. Insert the programmed microSD card to the DE1-SoC board
3. Set the MSEL[4:0] on your DE1-SoC to 00000
4. Connect a VGA monitor to the DE1-SoC board
5. Conect USB mouse and keyboard to the USB ports on the board
6. Power on the board and you will see the Lubuntu graphical environment

Additional information:
1. You can read the DE1-SoC-Getting_Started_Guide.pdf in the system CD for more details about setting up the Board
2. The Quartus project is built in Quartus II v16.0. The project is located at /Demonstrations/SOC_FPGA/DE1_SOC_Linux_FB (rev.F Board,version 5.1.1)
3. The Linux kernel version is 4.5. You can get the kernel source code from https://github.com/altera-opensource/linux-socfpga 
4. The default password for the ubuntu user is temppwd