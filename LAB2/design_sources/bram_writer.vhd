library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE := 16
    );
    port (
        clk  : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE :=16
        );
        port (
            clk     : in std_logic;
            aresetn : in std_logic;
    
            addr    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout    : out std_logic_vector(7 downto 0);
            din     : in std_logic_vector(7 downto 0);
            we      : in std_logic
        );
    end component;

    -- If the image has the largest dimension possible (= 256*256 pixels) ADDR_WIDTH must be = 16 which is its maximum, in this case 2^16 = 65536 = 256*256. 
    -- The generic ADDR_WIDTH can be changed from the block design accordigly to the actual size of the image sent, so that the biggest number rapresentable with that address width is our image_dimension 
    constant dim_image : integer := 2**ADDR_WIDTH;       

    -- Signal of enum. type for FSM states:
        -- start     : either reset = '0' or waiting for some valid data to arrive 
        -- memory    : valid data is arriving and each gray pixel is uploaded in a cell of the memory
        -- write_ok  : tlast = '1' and the number of pixels loaded is the right one
        -- underflow : tlast = '1' and the number of pixels loaded is less than what it should have been
        -- overflow  : tlast = '1' and the number of pixels loaded is more than what it should have been
        -- conv      : waiting for the convolution of the loaded image to end so the next one can be loaded on the bram
        -- 3 different states at the end of te memory phase in order to cleary understand in what condition the FSM is

    type state_type is (start, memory, write_ok_state, overflow_state, underflow_state, conv);    
    signal current_state, next_state: state_type := start;

    -- Signal to count the number of pixels received and put in the bram. It has to be able to reach at least one number more than the right number of pixels (pixel_counter = dim_image - 1) 
    -- or it would not sense an overflow error
    signal pixel_counter   : integer range 0 to dim_image := 0;

    -- Signals for the bram 
    signal addr_bram       : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');       
    signal dout_bram       : std_logic_vector(7 downto 0);
    signal we_bram         : std_logic := '0'; 

begin
    
    -- The xpm bram in the bram controller has a 1 clock latency only on reading, not on writing

    bram : bram_controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk     => clk, 
            aresetn => aresetn,
            addr    => addr_bram, 
            dout    => dout_bram, 
            din     => s_axis_tdata,           
            we      => we_bram
        );

    -- Address given to the bram, in the writing phase it's the addr where to store the next pixel while during the convolution is the conv_addr requested by the convolution module  
    addr_bram     <= conv_addr when current_state = conv 
                     else std_logic_vector(to_unsigned(pixel_counter, ADDR_WIDTH)); 

    -- Process to control whether there is a reset or just a clock pulse 
    synchronousLogic : process (clk, aresetn)
    begin
        if aresetn = '0' then
            current_state  <= start; 
            pixel_counter  <= 0;
            we_bram        <= '0'; 
        elsif rising_edge(clk) then 
            -- Current state update
            current_state <= next_state;
        
            -- Updating the signals 
            if (current_state = memory or next_state = memory) and s_axis_tvalid = '1' then          
                we_bram       <= '1';
                -- If just next_sate = memory then the first pixel has just arrived and pixel_counter should not be incremented yet since that pixel should be stored at address 0
                if current_state = memory then                                                        
                   pixel_counter <= pixel_counter + 1;    
                end if;                                                  
            else 
                we_bram       <= '0';
            end if;

            -- Pixel_counter reset
            -- If convolution has ended a new image can be stored starting from addrss 0
            if current_state = conv and done_conv = '1' then                                     
                pixel_counter <= 0; 
            end if; 

        end if; 
    end process; 

    -- Process to select, for each state, which is the next state depending on the inputs 
    nextStateLogic   : process(current_state, s_axis_tlast, s_axis_tvalid, done_conv)
    begin

        -- Default
        next_state <= current_state;

        case (current_state) is 

            when start      => 
                if s_axis_tvalid = '1' then                         -- Valid data is coming from the C2G
                    next_state  <= memory; 
                end if; 

            when memory     => 
                if s_axis_tvalid = '1' and s_axis_tlast = '1' then  -- End of the image
                    -- The pixel counter will be increased in the next clock pulse with respect to when s_axis_tvalid is put = 1, and so it will anctually reach the value dim_image - 1 after this check is done 
                    -- (this check is done as soon as s_axis_tvalid and s_axis_tlast are = '1'), but the last pixel has actually already been received.
                    if pixel_counter + 1 = dim_image - 1 then       
                        next_state <= write_ok_state;
                    elsif pixel_counter + 1 > dim_image - 1 then     
                        next_state <= overflow_state; 
                    else
                        next_state <= underflow_state;
                    end if; 
                end if; 

            when write_ok_state   => 
                next_state <= conv; 

            when overflow_state | underflow_state  => 
                next_state <= conv;      
            
            when conv       =>
                -- Convolution has ended, so what is saved in the memory is not needed anymore and another image can be received and stored
                if done_conv = '1' then                             
                    next_state <= start; 
                end if; 
    
        end case; 
    end process; 

    -- Process to specify the outputs for each state
    outputLogic      : process(current_state)
    begin

        -- Default
        start_conv    <= '0';
        write_ok      <= '0';
        overflow      <= '0';
        underflow     <= '0';
        s_axis_tready <= '0';
        conv_data     <= (others => '0');

        case (current_state) is

            when start      => 
                -- The module is ready to receive data: either there are no pixels in the memory or they can be overwritten because they have already been processed
                s_axis_tready   <= '1';                              
               
            when memory     => 
                s_axis_tready   <= '1';
            
            when write_ok_state   => 
                start_conv      <= '1';
                write_ok        <= '1';

            when overflow_state   => 
                start_conv      <= '1';
                overflow        <= '1';
            
            when underflow_state  =>   
                start_conv      <= '1';
                underflow       <= '1';
            
            when conv       =>   
                -- New data can't be received while the convolution is processing the previous image, to s_axis_tready remains = '0'                                                          
                conv_data       <= dout_bram(6 downto 0);                
            end case; 

    end process; 

end architecture;