library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_controller is
	Generic (
		LED_WIDTH		: positive := 8
	);
	Port (
		mute_enable		: in std_logic;
		filter_enable	: in std_logic;

		led_r			: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_g			: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_b			: out std_logic_vector(LED_WIDTH-1 downto 0)
	);
end led_controller;

architecture Behavioral of led_controller is

begin

	-- LED control process: sets the LED colors based on the mute and filter states
	-- Mute state: Red LED on, Green and Blue LEDs off
	-- Filter state: Blue LED on, Red and Green LEDs off
	-- Normal state: Green LED on, Red and Blue LEDs off
	process (mute_enable, filter_enable)
	begin
		if mute_enable = '1' then
			led_r <= (others => '1');
			led_g <= (others => '0');
			led_b <= (others => '0');

		elsif filter_enable = '1' then
			led_r <= (others => '0');
			led_g <= (others => '0');
			led_b <= (others => '1'); 
		else
			led_r <= (others => '0');
			led_g <= (others => '1'); 
			led_b <= (others => '0');
		end if;
	end process;

end Behavioral;
