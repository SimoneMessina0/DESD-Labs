	library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.numeric_std.all; 

	entity digilent_jstk2 is
		generic (
			DELAY_US		: integer := 25;    		-- Delay (in us) between two packets 
			CLKFREQ		 	: integer := 100_000_000;  	-- Frequency of the aclk signal (in Hz)
			SPI_SCLKFREQ 	: integer := 66_000 		-- Frequency of the SPI Saclk clock signal (in Hz)
		);
		Port ( 
			aclk 			: in  STD_LOGIC;
			aresetn			: in  STD_LOGIC;

			-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
			m_axis_tvalid	: out STD_LOGIC;
			m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
			m_axis_tready	: in  STD_LOGIC;

			-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
			-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
			s_axis_tvalid	: in STD_LOGIC;
			s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

			-- Joystick and button values read from the module
			jstk_x			: out std_logic_vector(9 downto 0);
			jstk_y			: out std_logic_vector(9 downto 0);
			btn_jstk		: out std_logic;
			btn_trigger		: out std_logic;

			-- LED color to send to the module
			led_r			: in std_logic_vector(7 downto 0);
			led_g			: in std_logic_vector(7 downto 0);
			led_b			: in std_logic_vector(7 downto 0)		
		);
	end digilent_jstk2;

	architecture Behavioral of digilent_jstk2 is

		-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
		constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";
		-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).

		--[----------------------------------------------------------------------------------------------------------]
			
		--FIFO parameters. 
		--PACKET WIDTH: number of bytes received in a burst of data
		--DATA_WIDTH: number of bits of each packet, in this case it is 8 so one byte
		constant SPI_PACKET_WIDTH 	: positive := 5; 
		constant SPI_DATA_WIDTH 	: positive := 8;
		
		--Creation of the FIFO type. It is used both in input and output. 
		type SPI_FIFO is array (0 to SPI_PACKET_WIDTH-1) of std_logic_vector(SPI_DATA_WIDTH-1 downto 0);

		--[---------------------------------SIGNALS TO SEND COMMANDS TO THE JOYSTICK---------------------------------]
		--Initialization of the FIFO to put out data. Initially it is completely filled with 0. 
		signal output_fifo : SPI_FIFO	:= (others=>(others=>'0'));  

		--Creation of the index of the ring buffer
		signal ring_counter_master      : integer range 0 to SPI_PACKET_WIDTH := 0;
		
		--Values to better understand what the ring buffer is doing
		constant COMMAND_0				: integer := 0;
		constant PARAM_1				: integer := 1;
		constant PARAM_2				: integer := 2;
		constant PARAM_3				: integer := 3;
		constant PARAM_4				: integer := 4;
		constant MASTER_WAIT 			: integer := 5;

		--Signal to buffer the value of the TVALID of the master interface
		signal m_axis_tvalid_readable   : std_logic := '0'; 

		--Flag to advise that the counter has reached the requested delay value 
		signal counting_ended  	: std_logic := '0'; 

		-- Inter-packet delay plus the time needed to transfer 1 byte (for the CS de-assertion)
 		constant DELAY_CYCLES : integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;

		--Counter to introduce the delay between packets of data. 
		signal counter 			: integer range 0 to DELAY_CYCLES := 0; 

		--[---------------------------------SIGNALS FOR INCOMING DATA INTERFACE--------------------------------------]
		--Initialization of the FIFO for the incoming data. Initially it is completely filled with 0. 
		signal input_fifo : SPI_FIFO	:= (others=>(others=>'0'));
		
		--Creation of the index of the ring buffer
		signal ring_counter_slave 		: integer range 0 to SPI_PACKET_WIDTH-1 := 0;

		--Values to better understand what the ring buffer is doing
		constant smpX_LB				: integer := 0;
		constant smpX_HB				: integer := 1;
		constant smpY_LB				: integer := 2;
		constant smpY_HB				: integer := 3;
		constant fsButtons				: integer := 4;

		--[---------------------------------SIGNALS TO READ THE 10 BITS OF THE JOYSTICK------------------------------]
		signal jstk_x_temp			:  std_logic_vector(9 downto 0) := (others => '0'); 
		signal jstk_y_temp			:  std_logic_vector(9 downto 0) := (others => '0');

	begin

		--------------------------------------------------------------------------------------------------------------
		--[*********************************SENDING OF COMMANDS TO THE JOYSTICK**************************************]
		--------------------------------------------------------------------------------------------------------------

		--Assignment of the TVALID to the signal have a readable value 
		m_axis_tvalid <= m_axis_tvalid_readable; 

		output_data_process : process(aclk,aresetn)
		begin 
			if aresetn = '0' then
				
				m_axis_tvalid_readable 			<= '0'; 
				ring_counter_master 			<= COMMAND_0;

			elsif rising_edge(aclk) then 

				--In the way that the output FIFO is implemented, the TVALID is always high because
				--valid data is always on the output except for when, between packets, 225 us must be waited. 
				--In that period of time, output data not considered valid.
				-- VHDL Signal commit is exploited to overwrite the TVALID when necessary. 
				m_axis_tvalid_readable <= '1'; 

				--When TREADY and TVALID are active the ring counter is incremented, because 
				--the data that was on the ring buffer has been sent, the handshake and transfer has 
				--happened so the output data can be changed. 
				if m_axis_tready = '1' and m_axis_tvalid_readable = '1' then
					ring_counter_master <= ring_counter_master + 1; 
				end if;

				--When the ring counter reaches the value after which the last parameter has been sent, 
				--the TVALID is deasserted.  
				if ring_counter_master = MASTER_WAIT and counting_ended = '0' then
					--VHDL Signal commit is exploited here to overwrite the TVALID when necessary 
					m_axis_tvalid_readable <= '0'; 
				end if; 

				--When the delay has ended, the COMMAND_0 value is assigned to the ring value
				if ring_counter_master = MASTER_WAIT and counting_ended = '1' then
					ring_counter_master <= COMMAND_0; 
				end if; 

				--Assignment of the values to send to the FIFO
				output_fifo(COMMAND_0) 		<= CMDSETLEDRGB; 
				output_fifo(PARAM_1) 		<= led_r; 
				output_fifo(PARAM_2) 		<= led_g;
				output_fifo(PARAM_3) 		<= led_b;
				output_fifo(PARAM_4) 		<= (others => '0');

			end if;
		end process; 

		--On the data bus to the SPI IP core we always place the value of the FIFO associated
		--with the specific value of the ring counter, except in the moment of the MASTER_WAIT where 
		--dummy data is inserted
		m_axis_tdata <= (others=>'0') when ring_counter_master = MASTER_WAIT else
						output_fifo(ring_counter_master); 

		--Process to create the intra-packet delay set by the generic
		delay_process : process(aclk)
		begin 
			if rising_edge(aclk) then
				if ring_counter_master = MASTER_WAIT then 
					if counter >= DELAY_CYCLES-1 then 
						counting_ended <= '1'; 
					else 
						counter <= counter + 1;
					end if; 
				else
					counting_ended <= '0';
					counter <= 0;
				end if; 
			end if; 
		end process;

		--------------------------------------------------------------------------------------------------------------
		--[***********************************RECEIVING DATA FROMHE JOYSTICK*****************************************]
		--------------------------------------------------------------------------------------------------------------
		process(aclk)
		begin
			if aresetn = '0' then
				
				-- The first byte it is going to be received is the low byte of the X-axis of the joystick
				ring_counter_slave 	<= smpX_LB; 
				jstk_x				<= (others=>'0'); 
				jstk_y				<= (others=>'0');

			elsif rising_edge(aclk) then

				--If TVALID is active... 
				if s_axis_tvalid = '1' then
					--...valid data has been received and must be saved in the corrisponding FIFO position...
					input_fifo(ring_counter_slave) <= s_axis_tdata; 

					--... and the ring counter is incremented 
					ring_counter_slave <= ring_counter_slave + 1; 

					--If in the previous clock cycle the information that has been written is the fifth byte, 
					--the counter must be reset and must be ready to write in the FIFO the first byte of incoming data
					if ring_counter_slave = fsButtons then
						ring_counter_slave <= smpX_LB; 
					end if; 
				end if; 

				--Padding of the 8+2 bits coming from the SPI value with the joystick axis information
				--it must be updated as soon as the LSB byte of the value has been received, so that's why it 
				--is done at that specific value of the ring value corresponding to the successive bit reading
				if ring_counter_slave = smpY_LB and aresetn = '1' then 
					jstk_x <= input_fifo(smpX_HB)(1 downto 0) & input_fifo(smpX_LB)(7 downto 0); 
				end if;

				if ring_counter_slave = fsButtons and aresetn = '1' then  
					jstk_y <= input_fifo(smpY_HB)(1 downto 0) & input_fifo(smpY_LB)(7 downto 0); 
				end if;

			end if; 
		end process; 

		--[--------------------------------------MUXING OF THE JOYTICK BUTTONS----------------------------------------]
		--As soon as the fsButton is received, based on its value, the corresponding output is updated 
		btn_jstk 	<= 	'1' when input_fifo(fsButtons) = "00000001" or input_fifo(fsButtons) = "00000011" else 
						'0';	 
		btn_trigger <= 	'1' when input_fifo(fsButtons) = "00000010" or input_fifo(fsButtons) = "00000011" else 
						'0';		

	end architecture;