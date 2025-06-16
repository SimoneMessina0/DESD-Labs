----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/29/2024 10:12:03 AM
-- Design Name: 
-- Module Name: effect_selector - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity effect_selector is
    generic (
        JOYSTICK_LENGHT : integer := 10
    );
    port (
        aclk       : in std_logic;
        aresetn    : in std_logic;
        effect     : in std_logic;
        jstck_x    : in std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
        jstck_y    : in std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
        volume     : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
        balance    : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
        lfo_period : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0)
    );
end effect_selector;

architecture Behavioral of effect_selector is

begin

    process (aclk, aresetn)
    begin
        if aresetn = '0' then
            volume     <= (others => '0');
            balance    <= (others => '0');
            lfo_period <= (others => '0');
        elsif rising_edge(aclk) then
            if effect = '0' then
                volume  <= jstck_y;
                balance <= jstck_x;
			elsif effect = '1' then
                lfo_period <= jstck_y;
            end if;
        end if;
    end process;
end Behavioral;
