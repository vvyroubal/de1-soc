-- SPDX-License-Identifier: GPL-2.0-or-later
-- Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
--------------------------------------------------------------------------------
-- marquee_top.vhd
--
-- DE1-SoC standalone FPGA design (no HPS required).
-- Scrolls an arbitrary text string right-to-left across the six 7-segment
-- displays (HEX5 = leftmost ... HEX0 = rightmost), like a marquee sign.
--
-- The message is the MESSAGE generic (default "debian 13"): edit it here, or
-- override the generic, to display any text. Each character is looked up in a
-- 7-segment font; characters with no legible seven-segment form (e.g. K M V W X)
-- show as blank. The message is padded with a blank screen on each side so it
-- scrolls fully in from the right and off to the left before repeating.
--
-- KEY0 (active-low push button) restarts the scroll from the beginning.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity marquee_top is
    generic (
        -- Text to scroll. Digits 0-9 and most letters render; unsupported
        -- characters display blank. Case is chosen per letter for legibility.
        MESSAGE : string := "debian 13"
    );
    port (
        CLOCK_50 : in  std_logic;                      -- 50 MHz oscillator
        KEY      : in  std_logic_vector(3 downto 0);   -- push buttons, active low
        HEX0     : out std_logic_vector(6 downto 0);   -- rightmost (segments a..g, active low)
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0);
        HEX4     : out std_logic_vector(6 downto 0);
        HEX5     : out std_logic_vector(6 downto 0)    -- leftmost
    );
end entity marquee_top;

architecture rtl of marquee_top is

    constant CLK_HZ   : integer := 50_000_000;
    -- Advance one character every STEP_MS milliseconds (~3.3 chars/sec at 300).
    constant STEP_MS  : integer := 300;
    constant STEP_MAX : integer := (CLK_HZ / 1000) * STEP_MS - 1;

    -- All segments off (displays are active low, so '1' = off).
    constant BLANK : std_logic_vector(6 downto 0) := "1111111";

    -- Pad the message with one blank screen (6 columns) on each side so it
    -- enters from the right and clears the left edge before repeating.
    constant PAD     : string(1 to 6) := "      ";
    constant TEXT    : string         := PAD & MESSAGE & PAD;
    -- A 6-wide window slides over TEXT at positions 1 .. TEXT'length-5.
    constant POS_MAX : integer        := TEXT'length - 5;

    -- Character -> 7-segment pattern. Bit 0 = segment a ... bit 6 = segment g;
    -- active low ('0' lights the segment). Where only one case reads cleanly on
    -- seven segments, both cases map to that glyph; b/d/n/etc. are lowercase
    -- because their uppercase forms are indistinguishable from digits.
    function glyph(c : character) return std_logic_vector is
    begin
        case c is
            when '0'       => return "1000000";
            when '1'       => return "1111001";
            when '2'       => return "0100100";
            when '3'       => return "0110000";
            when '4'       => return "0011001";
            when '5' | 'S' | 's' => return "0010010";   -- 5 / S
            when '6'       => return "0000010";
            when '7'       => return "1111000";
            when '8'       => return "0000000";
            when '9'       => return "0010000";
            when 'A'       => return "0001000";          -- A
            when 'a'       => return "0100000";          -- a
            when 'B' | 'b' => return "0000011";          -- b
            when 'C'       => return "1000110";          -- C
            when 'c'       => return "0100111";          -- c
            when 'D' | 'd' => return "0100001";          -- d
            when 'E'       => return "0000110";          -- E
            when 'e'       => return "0000100";          -- e
            when 'F' | 'f' => return "0001110";          -- F
            when 'G' | 'g' => return "1000010";          -- G
            when 'H'       => return "0001001";          -- H
            when 'h'       => return "0001011";          -- h
            when 'I' | 'l' => return "1111001";          -- I / l (bare bar, like 1)
            when 'i'       => return "1111011";          -- i (single segment)
            when 'J' | 'j' => return "1100001";          -- J
            when 'L'       => return "1000111";          -- L
            when 'N' | 'n' => return "0101011";          -- n
            when 'O'       => return "1000000";          -- O (= 0)
            when 'o'       => return "0100011";          -- o
            when 'P' | 'p' => return "0001100";          -- P
            when 'q' | 'Q' => return "0011000";          -- q
            when 'R' | 'r' => return "0101111";          -- r
            when 'T' | 't' => return "0000111";          -- t
            when 'U'       => return "1000001";          -- U
            when 'u' | 'v' | 'V' => return "1100011";    -- u (also best-effort v)
            when 'Y' | 'y' => return "0010001";          -- y
            when '-'       => return "0111111";          -- minus
            when '_'       => return "1110111";          -- underscore
            when ' '       => return BLANK;
            when others    => return BLANK;              -- no legible 7-seg form
        end case;
    end function glyph;

    signal reset_n  : std_logic;
    signal step_cnt : integer range 0 to STEP_MAX := 0;
    signal pos      : integer range 1 to POS_MAX := 1;

begin

    reset_n <= KEY(0);   -- hold KEY0 to restart the scroll

    ----------------------------------------------------------------------------
    -- Scroll engine: advance the window one character every STEP_MS, wrapping.
    ----------------------------------------------------------------------------
    scroll_proc : process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            step_cnt <= 0;
            pos      <= 1;
        elsif rising_edge(CLOCK_50) then
            if step_cnt = STEP_MAX then
                step_cnt <= 0;
                if pos = POS_MAX then
                    pos <= 1;
                else
                    pos <= pos + 1;
                end if;
            else
                step_cnt <= step_cnt + 1;
            end if;
        end if;
    end process scroll_proc;

    ----------------------------------------------------------------------------
    -- Drive the six displays from the sliding window. HEX5 = leftmost column.
    ----------------------------------------------------------------------------
    HEX5 <= glyph(TEXT(pos));
    HEX4 <= glyph(TEXT(pos + 1));
    HEX3 <= glyph(TEXT(pos + 2));
    HEX2 <= glyph(TEXT(pos + 3));
    HEX1 <= glyph(TEXT(pos + 4));
    HEX0 <= glyph(TEXT(pos + 5));

end architecture rtl;
