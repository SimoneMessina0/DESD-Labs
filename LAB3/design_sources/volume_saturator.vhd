library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_saturator is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND	: integer  := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer  := -2**23    -- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end volume_saturator;

architecture Behavioral of volume_saturator is

	-- signals for AXI
	signal s_tready_reg : std_logic := '0';
	signal m_tvalid_reg : std_logic := '0';
	signal m_tlast_reg  : std_logic := '0';

begin

	-- Assignation of AXI signals
	s_axis_tready <= s_tready_reg;
	m_axis_tvalid <= m_tvalid_reg;
	m_axis_tlast  <= m_tlast_reg;

	process (aclk, aresetn)
	begin

		if aresetn = '0' then 
			-- Reset of the signals
			s_tready_reg    <= '1';
			m_tvalid_reg    <= '0';
			m_axis_tdata    <= (others => '0');
			m_tlast_reg     <= '0';

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
				m_tlast_reg       <= s_axis_tlast; 	
				-- manually saturating the output
				if signed(s_axis_tdata) > HIGHER_BOUND then 
					m_axis_tdata <= std_logic_vector(to_signed(HIGHER_BOUND, TDATA_WIDTH));
				elsif signed(s_axis_tdata) < LOWER_BOUND then 
					m_axis_tdata <= std_logic_vector(to_signed(LOWER_BOUND, TDATA_WIDTH)); 
				else 
					m_axis_tdata <= s_axis_tdata(TDATA_WIDTH-1 downto 0); 
				end if; 
			end if; 

		end if; 

	end process;

end Behavioral;
