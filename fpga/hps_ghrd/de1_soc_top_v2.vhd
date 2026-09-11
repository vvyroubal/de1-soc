-- Minimal DE1-SoC top level matching the actual generated de1_soc.qsys
-- component: SDIO + UART0 peripherals, full 32-bit DDR3 memory interface,
-- BOOTFROMFPGA_Enable=0. No other peripherals enabled. Purpose: give the
-- HPS component a properly-instantiated presence in the fabric so
-- f2h_boot_from_fpga_on_failure gets a defined value instead of floating.

library ieee;
use ieee.std_logic_1164.all;

entity DE1_SoC_top_v2 is
port(
  CLOCK_50 : in std_logic;

  HPS_DDR3_ADDR    : out   std_logic_vector(14 downto 0);
  HPS_DDR3_BA      : out   std_logic_vector(2 downto 0);
  HPS_DDR3_CAS_N   : out   std_logic;
  HPS_DDR3_CK_N    : out   std_logic;
  HPS_DDR3_CK_P    : out   std_logic;
  HPS_DDR3_CKE     : out   std_logic;
  HPS_DDR3_CS_N    : out   std_logic;
  HPS_DDR3_DM      : out   std_logic_vector(3 downto 0);
  HPS_DDR3_DQ      : inout std_logic_vector(31 downto 0);
  HPS_DDR3_DQS_N   : inout std_logic_vector(3 downto 0);
  HPS_DDR3_DQS_P   : inout std_logic_vector(3 downto 0);
  HPS_DDR3_ODT     : out   std_logic;
  HPS_DDR3_RAS_N   : out   std_logic;
  HPS_DDR3_RESET_N : out   std_logic;
  HPS_DDR3_RZQ     : in    std_logic;
  HPS_DDR3_WE_N    : out   std_logic;

  HPS_SD_CLK  : out   std_logic;
  HPS_SD_CMD  : inout std_logic;
  HPS_SD_DATA : inout std_logic_vector(3 downto 0);

  HPS_UART_RX : in  std_logic;
  HPS_UART_TX : out std_logic
);
end entity DE1_SoC_top_v2;

architecture rtl of DE1_SoC_top_v2 is
  component de1_soc is
    port (
      clk_clk                     : in    std_logic := 'X';
      hps_0_h2f_reset_reset_n     : out   std_logic;
      hps_io_hps_io_sdio_inst_CMD : inout std_logic := 'X';
      hps_io_hps_io_sdio_inst_D0  : inout std_logic := 'X';
      hps_io_hps_io_sdio_inst_D1  : inout std_logic := 'X';
      hps_io_hps_io_sdio_inst_CLK : out   std_logic;
      hps_io_hps_io_sdio_inst_D2  : inout std_logic := 'X';
      hps_io_hps_io_sdio_inst_D3  : inout std_logic := 'X';
      hps_io_hps_io_uart0_inst_RX : in    std_logic := 'X';
      hps_io_hps_io_uart0_inst_TX : out   std_logic;
      memory_mem_a                : out   std_logic_vector(14 downto 0);
      memory_mem_ba               : out   std_logic_vector(2 downto 0);
      memory_mem_ck                : out   std_logic;
      memory_mem_ck_n              : out   std_logic;
      memory_mem_cke               : out   std_logic;
      memory_mem_cs_n              : out   std_logic;
      memory_mem_ras_n             : out   std_logic;
      memory_mem_cas_n             : out   std_logic;
      memory_mem_we_n              : out   std_logic;
      memory_mem_reset_n           : out   std_logic;
      memory_mem_dq                : inout std_logic_vector(31 downto 0) := (others => 'X');
      memory_mem_dqs                : inout std_logic_vector(3 downto 0)  := (others => 'X');
      memory_mem_dqs_n              : inout std_logic_vector(3 downto 0)  := (others => 'X');
      memory_mem_odt                : out   std_logic;
      memory_mem_dm                 : out   std_logic_vector(3 downto 0);
      memory_oct_rzqin              : in    std_logic := 'X';
      reset_reset_n                 : in    std_logic := 'X'
    );
  end component de1_soc;

  signal hps_reset_n : std_logic;
begin

  hps_reset_n <= '1';

  de1_soc_inst : de1_soc
   port map(
      clk_clk                     => CLOCK_50,
      hps_0_h2f_reset_reset_n     => open,
      hps_io_hps_io_sdio_inst_CMD => HPS_SD_CMD,
      hps_io_hps_io_sdio_inst_D0  => HPS_SD_DATA(0),
      hps_io_hps_io_sdio_inst_D1  => HPS_SD_DATA(1),
      hps_io_hps_io_sdio_inst_CLK => HPS_SD_CLK,
      hps_io_hps_io_sdio_inst_D2  => HPS_SD_DATA(2),
      hps_io_hps_io_sdio_inst_D3  => HPS_SD_DATA(3),
      hps_io_hps_io_uart0_inst_RX => HPS_UART_RX,
      hps_io_hps_io_uart0_inst_TX => HPS_UART_TX,
      memory_mem_a                => HPS_DDR3_ADDR,
      memory_mem_ba                => HPS_DDR3_BA,
      memory_mem_ck                => HPS_DDR3_CK_P,
      memory_mem_ck_n              => HPS_DDR3_CK_N,
      memory_mem_cke               => HPS_DDR3_CKE,
      memory_mem_cs_n              => HPS_DDR3_CS_N,
      memory_mem_ras_n             => HPS_DDR3_RAS_N,
      memory_mem_cas_n             => HPS_DDR3_CAS_N,
      memory_mem_we_n              => HPS_DDR3_WE_N,
      memory_mem_reset_n           => HPS_DDR3_RESET_N,
      memory_mem_dq                => HPS_DDR3_DQ,
      memory_mem_dqs                => HPS_DDR3_DQS_P,
      memory_mem_dqs_n              => HPS_DDR3_DQS_N,
      memory_mem_odt                => HPS_DDR3_ODT,
      memory_mem_dm                 => HPS_DDR3_DM,
      memory_oct_rzqin              => HPS_DDR3_RZQ,
      reset_reset_n                 => hps_reset_n
  );

end architecture rtl;
