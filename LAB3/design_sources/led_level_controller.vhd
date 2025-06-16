library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_level_controller is
    generic(

        NUM_LEDS            : positive := 16;
        CHANNEL_LENGHT      : positive := 24;
        refresh_time_ms     : positive :=1;
        clock_period_ns     : positive :=10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led             : out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic
    );
end led_level_controller;

architecture Behavioral of led_level_controller is

    --Constant to compute the number of clock cycles to be waited between the refresh of 
    --of the leds
    constant N_CLK_CYCLES : positive := (refresh_time_ms * 10**6) / clock_period_ns;

    --Input buffer datatype creation
    type FIFO_in is array (0 to 1) of std_logic_vector(CHANNEL_LENGHT-1 downto 0); 
    --buffer initialization to 0
    signal input_buffer : FIFO_in := (others=>(others=>'0')); 

    --Constant creation relative to the position in the buffer to make the code more readable
    constant CH_L   : integer := 0; 
    constant CH_R   : integer := 1; 

    --Creation of a signal to read the state of TREADY in order to avoid AXI violations
    signal s_axis_tready_readable   : std_logic := '0'; 

    --Signal for sum computation 
    signal sum               : unsigned(CHANNEL_LENGHT-1 downto 0); 
    --Signal for average computation
    signal average           : unsigned(CHANNEL_LENGHT-1 downto 0);

    --Signal to be able to use the counter value out of the process 
    signal counter_signal      : integer range 0 to CHANNEL_LENGHT  := 0;  

    --Signal to count up the number of cycles to wait to implement the delay 
    signal counter_cycles : integer range 0 to N_CLK_CYCLES := 0;

begin

    --Creation of the TREADY readable value 
    s_axis_tready <= s_axis_tready_readable; 

    --Process for data elaboration
    data_elaboration_process : process(aresetn,aclk)
        variable counter : integer range 0 to CHANNEL_LENGHT:= 0; 
    begin
        if aresetn = '0' then
            
            sum                         <= (others=>'0'); 
            s_axis_tready_readable      <= '1';
            average                     <= (others=>'0');

        elsif rising_edge(aclk) then
            if s_axis_tvalid = '1' then 

                --Based on the value of TLAST the data of the left channel or of the right channel is received
                if s_axis_tlast = '0' then 
                    input_buffer(CH_L) <= s_axis_tdata; 
                elsif s_axis_tlast = '1' then
                    input_buffer(CH_R) <= s_axis_tdata;
                end if;

                --Then the sum of the absolute values of the channel data is computed 
                sum <= unsigned(abs(signed(input_buffer(CH_L)))+abs(signed(input_buffer(CH_R)))); 
 
                --And the average of the two values
                average <= '0' & sum(CHANNEL_LENGHT-1 downto 1); 

                --Initialization of the counter value 
                counter := 0; 

                --Via this for loop a proximity encoder is implemented to compute how many leds 
                --must be turned on 
                for i in 0 to sum'LENGTH-1 loop
                    if average(i) = '1' then
                        counter := i;
                    end if;
                end loop;

                counter_signal <= counter;

            end if; 
        end if; 
    end process; 
    
    --Process for delay implementation 
    delay : process (aclk, aresetn)
    begin
        if aresetn = '0' then
            led             <= (Others => '0');
            counter_cycles  <= 0;
        elsif rising_edge(aclk) then

            counter_cycles <= counter_cycles + 1;

            --When the counter reaches the correct number of cycles to implement the delay...
            if counter_cycles = N_CLK_CYCLES - 1 then 
                counter_cycles  <= 0; 

                --...the value on the leds is updated
                if (counter_signal > 8 and counter_signal < 16) then
                    --using the counter value it is known how many leds should be on 
                    --and how many should be off. Instead of computing a power, an aggregate is used to 
                    --assign the states of the leds 
                    led(led'high downto counter_signal - 8)         <= (others=>'0');
                    led(counter_signal - 8 - 1 downto 0)            <= (others=>'1'); 

                    --Here's an example 
                    -- counter_signal = 9:
                    -- (led'high downto (9-8)) = '0' ===> (led'high downto 1) = '0'
                    -- ((9 - 8 - 1) downto 0) = '1'  ===> (0 downto 0) = '1'

                --since the maximum value reached by the channel values
                --is never 2^24-1, one more led is turned on when the counter signal is >= 16
                elsif counter_signal > 15 then

                    led(led'high downto counter_signal - 8 + 1)     <= (others=>'0');
                    led(counter_signal - 8 downto 0)                <= (others=>'1'); 

                else
                --in any other case, all the leds should be off
                    led <= (others=>'0');

                end if;
            end if;
        end if;
    end process delay;

end Behavioral;