-- SPDX-License-Identifier: GPL-2.0-or-later
-- Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
--------------------------------------------------------------------------------
-- countdown_top.vhd
--
-- DE1-SoC standalone FPGA design (no HPS required).
-- Counts DOWN from 100 to 0, once per second, then wraps back to 100 and repeats.
-- The value is shown in decimal on the three right-hand 7-segment displays:
--
--     HEX2 = hundreds   HEX1 = tens   HEX0 = ones      (HEX5..HEX3 blank)
--
-- Leading zeros are blanked, so the sequence reads 100, 99, ... 10, 9, ... 1, 0.
--
-- KEY0 (active-low push button) resets the count to 100.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity countdown_top is
    port (
        CLOCK_50 : in  std_logic;                      -- 50 MHz oscillator
        KEY      : in  std_logic_vector(3 downto 0);   -- push buttons, active low
        HEX0     : out std_logic_vector(6 downto 0);   -- ones    (segments a..g, active low)
        HEX1     : out std_logic_vector(6 downto 0);   -- tens
        HEX2     : out std_logic_vector(6 downto 0);   -- hundreds
        HEX3     : out std_logic_vector(6 downto 0);   -- blank
        HEX4     : out std_logic_vector(6 downto 0);   -- blank
        HEX5     : out std_logic_vector(6 downto 0)    -- blank
    );
end entity countdown_top;

architecture rtl of countdown_top is

    -- One second at 50 MHz.  Change TICK_MAX to alter the count rate:
    --   2 counts/sec -> CLK_HZ/2 - 1,  1 count/2 sec -> CLK_HZ*2 - 1, etc.
    constant CLK_HZ   : integer := 50_000_000;
    constant TICK_MAX : integer := CLK_HZ - 1;

    signal reset_n  : std_logic;
    signal tick_cnt : integer range 0 to TICK_MAX := 0;
    signal one_hz   : std_logic := '0';                -- single-cycle enable, 1 Hz
    signal count    : integer range 0 to 100 := 100;   -- the displayed value

    -- All segments off (displays are active low, so '1' = off).
    constant BLANK : std_logic_vector(6 downto 0) := "1111111";

    -- Decimal digit -> 7-segment pattern.  Bit 0 = segment a ... bit 6 = segment g.
    function seg7(d : integer range 0 to 9) return std_logic_vector is
    begin
        case d is
            when 0 => return "1000000";
            when 1 => return "1111001";
            when 2 => return "0100100";
            when 3 => return "0110000";
            when 4 => return "0011001";
            when 5 => return "0010010";
            when 6 => return "0000010";
            when 7 => return "1111000";
            when 8 => return "0000000";
            when 9 => return "0010000";
            when others => return BLANK;
        end case;
    end function seg7;

    signal huns, tens, ones : integer range 0 to 9;

begin

    reset_n <= KEY(0);   -- hold KEY0 to reset the count to 100

    ----------------------------------------------------------------------------
    -- 1 Hz enable generator: pulse one_hz high for a single clock every second.
    ----------------------------------------------------------------------------
    tick_proc : process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            tick_cnt <= 0;
            one_hz   <= '0';
        elsif rising_edge(CLOCK_50) then
            if tick_cnt = TICK_MAX then
                tick_cnt <= 0;
                one_hz   <= '1';
            else
                tick_cnt <= tick_cnt + 1;
                one_hz   <= '0';
            end if;
        end if;
    end process tick_proc;

    ----------------------------------------------------------------------------
    -- Down counter: 100 -> 0 -> 100 -> ...  (one step per one_hz pulse)
    ----------------------------------------------------------------------------
    count_proc : process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            count <= 100;
        elsif rising_edge(CLOCK_50) then
            if one_hz = '1' then
                if count = 0 then
                    count <= 100;
                else
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process count_proc;

    ----------------------------------------------------------------------------
    -- Binary -> BCD (count is 0..100, so hundreds is only ever 0 or 1).
    ----------------------------------------------------------------------------
    huns  <= count / 100;
    tens  <= (count / 10) mod 10;
    ones <= count mod 10;

    ----------------------------------------------------------------------------
    -- Drive the displays, blanking leading zeros.
    ----------------------------------------------------------------------------
    HEX0 <= seg7(ones);
    HEX1 <= BLANK when count < 10  else seg7(tens);
    HEX2 <= BLANK when count < 100 else seg7(huns);
    HEX3 <= BLANK;
    HEX4 <= BLANK;
    HEX5 <= BLANK;

end architecture rtl;
