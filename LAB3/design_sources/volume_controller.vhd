library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**23		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_controller;

architecture Behavioral of volume_controller is

	component volume_multiplier is
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
	end component;

	component volume_saturator is
		Generic (
			TDATA_WIDTH		: positive := 24;
			VOLUME_WIDTH	: positive := 10;
			VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
			HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
			LOWER_BOUND		: integer := -2**23		-- Inclusive
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
	end component;

	-- signals for the volume_multiplier
	signal s_axis_tready_mul : std_logic; 

	signal m_axis_tvalid_mul : std_logic; 
	signal m_axis_tdata_mul  : std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
	signal m_axis_tlast_mul  : std_logic;   

begin
	

	-- the inputs from the axis are directly given to an istance of a volume_multiplier that computes the multiplication/division
	-- by the appropriate power of two of the s_axis_data depending on the value of the volume signal. The outputs of the multiplier 
	-- are then used as inputs of an instance of a volume_saturator in order to manually saturate the output value to the max (or the min)
	-- allowed by the dimension of the axis_data bus (TDATA_WIDTH bits)


	multiplier_inst : volume_multiplier
		generic map (
			TDATA_WIDTH		=> TDATA_WIDTH,
			VOLUME_WIDTH	=> VOLUME_WIDTH,
			VOLUME_STEP_2	=> VOLUME_STEP_2	-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		)

		port map (
			aclk		    => aclk, 	
			aresetn			=> aresetn,
	
			s_axis_tvalid	=> s_axis_tvalid,
			s_axis_tdata	=> s_axis_tdata, 
			s_axis_tlast	=> s_axis_tlast, 
			s_axis_tready   => s_axis_tready_mul, 
	
			m_axis_tvalid	=> m_axis_tvalid_mul, 
			m_axis_tdata	=> m_axis_tdata_mul,
			m_axis_tlast	=> m_axis_tlast_mul, 
			m_axis_tready	=> m_axis_tready,
	
			volume		    => volume
		);

	saturator_inst :  volume_saturator 
		generic map (
			TDATA_WIDTH		=> TDATA_WIDTH,
			VOLUME_WIDTH	=> VOLUME_WIDTH,
			VOLUME_STEP_2	=> VOLUME_STEP_2,   -- i.e., number_of_steps = 2**(VOLUME_STEP_2)
			HIGHER_BOUND	=> HIGHER_BOUND,	-- Inclusive  
			LOWER_BOUND		=> LOWER_BOUND	    -- Inclusive  
		)
		port map(
			aclk			=> aclk,
			aresetn			=> aresetn,
	
			s_axis_tvalid	=> m_axis_tvalid_mul,
			s_axis_tdata	=> m_axis_tdata_mul,
			s_axis_tlast	=> m_axis_tlast_mul,
			s_axis_tready	=> s_axis_tready,
	
			m_axis_tvalid	=> m_axis_tvalid,
			m_axis_tdata	=> m_axis_tdata,
			m_axis_tlast	=> m_axis_tlast,
			m_axis_tready	=> s_axis_tready_mul
		);

end Behavioral;
