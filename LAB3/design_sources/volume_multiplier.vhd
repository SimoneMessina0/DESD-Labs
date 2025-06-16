library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_multiplier is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_multiplier;

architecture Behavioral of volume_multiplier is

	-- constants 
	constant interval : integer := 2**(VOLUME_STEP_2);       -- lenght of each inteval within which we multiply/divide by the same power of 2
	constant offset   : integer := 2**(VOLUME_STEP_2-1);     -- until the absolute value of the signed_volume input reaches the offset value the input data is passed as it is without changing the volume

	-- signals for AXI
	signal s_tready_reg : std_logic := '0';
	signal m_tvalid_reg : std_logic := '0';
	signal m_tlast_reg  : std_logic := '0';
	-- Pipeline signal
    signal m_tlast_reg_pipeline  : std_logic := '0';

	-- signal to difine the two ranges, for volume in [0, 512] the joystick value is in the range [-512, 0] and so the division by 2^i is performed, while for volume in [512, 1023] the joystick value is in the range [0, 511] and so the multiplication by 2^i is performed
	signal volume_signed : signed(VOLUME_WIDTH-1 downto 0) := (others => '0');
	
	-- signal to correctly shift the input signal left or right 
	signal m_axis_tdata_signed   : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0) := (others => '0');

	-- signal to make the circuit pipelined
	signal m_axis_tdata_signed_pipeline   : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0) := (others => '0');

	-- signal to transform the input data in a signal of the same dimension of the output (necessarily laarger in order to correctly store the maximum value obtainable from the multiplication by 2**x)
	signal s_axis_tdata_extended : std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0) := (others => '0');

begin

	-- Assignation of AXI signals
	s_axis_tready <= s_tready_reg;
  	m_axis_tvalid <= m_tvalid_reg;
  	m_axis_tlast  <= m_tlast_reg;
  	m_axis_tdata  <= std_logic_vector(m_axis_tdata_signed_pipeline); 

	-- Extending the input signal
	s_axis_tdata_extended <= (s_axis_tdata_extended'HIGH downto s_axis_tdata'HIGH+1 => s_axis_tdata(s_axis_tdata'HIGH)) & s_axis_tdata; 

	-- Changing the interpretation of the volume input (which rapresents an unsigned value) in a signed value
	volume_signed <= signed(unsigned(volume) - 2**(VOLUME_WIDTH-1));
	
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
				-- the number of intervals for each half of the joystick range is = to the max value of i = 512/64 = (2^VOLUME_WIDTH/2)/2^6 = 2^((VOLUME_WIDTH-1)-VOLUME_STEP_2)
				for i in 0 to 2**(VOLUME_WIDTH - 1 - VOLUME_STEP_2) loop 
					-- if volume signed > 0 the input data is incresed by a fator 2**i, which is equivalent to shift a vector left by i bits
					if (i-1)*interval <= volume_signed - offset and volume_signed - offset < i*interval then  
						m_axis_tdata_signed <= shift_left(signed(s_axis_tdata_extended), i); 
					-- if volume signed < 0 the input data is decreased by a fator 2**i, which is equivalent to shift a vector right by i bits
					elsif -i*interval < volume_signed + offset  and volume_signed + offset <= -(i-1)*interval then         
						m_axis_tdata_signed <= shift_right(signed(s_axis_tdata_extended), i);
					end if; 
				end loop; 
				m_axis_tdata_signed_pipeline <= m_axis_tdata_signed;
			end if; 

		end if; 		


	end process; 

end Behavioral;
 