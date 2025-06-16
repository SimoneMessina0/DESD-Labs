library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is

	--constants 
	constant interval   : integer := 2**(BALANCE_STEP_2);       -- lenght of each inteval within which we multiply/divide by the same power of 2
	constant offset     : integer := 2**(BALANCE_STEP_2-1);     -- until the absolute value of the signed_volume input reaches the offset value the input data is passed as it is without changing the volume


	-- signals for AXI
	signal s_tready_reg : std_logic := '0';
	signal m_tvalid_reg : std_logic := '0';
	signal m_tlast_reg  : std_logic := '0';
	-- Pipeline signal
    signal m_tlast_reg_pipeline  : std_logic := '0';

	-- signal to difine the two ranges to decide which channel to leave unaltered and which to divide by 2**x. For balance in [0, 512] the joystick value is in the range [-512, 0], while for balance in [512, 1023] the joystick value is in the range [0, 511] 
	signal balance_signed : signed(BALANCE_WIDTH-1 downto 0) := (others => '0');

	-- signal to correctly shift the input signal right 
	signal m_axis_tdata_signed : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

	-- signal to make the circuit pipelined
	signal m_axis_tdata_signed_pipeline : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

begin

	-- Assignation of AXI signals
	s_axis_tready <= s_tready_reg;
  	m_axis_tvalid <= m_tvalid_reg;
  	m_axis_tlast  <= m_tlast_reg;
	m_axis_tdata  <= std_logic_vector(m_axis_tdata_signed_pipeline); 

	-- Changing the interpretation of the balance input (which rapresents an unsigned value) in a signed value
	balance_signed <= signed(unsigned(balance) - 2**(BALANCE_WIDTH-1));

	process (aclk, aresetn)
	begin 

		if aresetn = '0' then 
			-- Reset of the signals
			s_tready_reg        <= '1';
			m_tvalid_reg        <= '0';
			m_tlast_reg         <= '0';
			m_axis_tdata_signed <= (others => '0');

		elsif rising_edge(aclk) then 

			-- controlling if there was an handshake for the AXI and if it has the module is ready to receive new data while
			-- the output is not valid until we have another handshake
			if m_axis_tready = '1' and m_tvalid_reg = '1' then 
				s_tready_reg      <= '1';
				m_tvalid_reg      <= '0';
			end if; 
			-- controlling if there was an handshake for the AXI and if so changing the value of the output data, declaring 
			-- the output as valid while bloking the module to receive more data in because it is not ready until the operation 
			-- of updating the output is complete
			if s_axis_tvalid = '1' and s_tready_reg = '1' then  
				m_tvalid_reg      <= '1';
				s_tready_reg      <= '0';	
				m_tlast_reg_pipeline       <= s_axis_tlast; 		
				m_tlast_reg <= m_tlast_reg_pipeline;
				-- default
				m_axis_tdata_signed <= signed(s_axis_tdata); 
				m_axis_tdata_signed_pipeline<= m_axis_tdata_signed;
				-- if the tdata for the left channel has arrived and balance_signed is in the positive range we divide the channel by 2**i, otherwise nothing is changed
				if s_axis_tlast = '0' and balance_signed > 0 then 
					for i in 0 to 2**(BALANCE_WIDTH - 1 - BALANCE_STEP_2) loop
						if (i-1)*interval <= balance_signed - offset and balance_signed - offset < i*interval then        
							m_axis_tdata_signed <= shift_right(signed(s_axis_tdata), i);
						end if; 
					end loop; 
				-- if the tdata for the right channel has arrived and balance_signed is in the negative range we divide the channel by 2**i, otherwise nothing is changed
				elsif s_axis_tlast = '1' and balance_signed < 0 then 
				    for i in 0 to 2**(BALANCE_WIDTH - 1 - BALANCE_STEP_2) loop
						if -i*interval < balance_signed + offset  and balance_signed + offset <= -(i-1)*interval then         
							m_axis_tdata_signed <= shift_right(signed(s_axis_tdata), i);
						end if; 
					end loop; 
				end if;
			end if; 
		end if; 

	end process; 

end Behavioral;
