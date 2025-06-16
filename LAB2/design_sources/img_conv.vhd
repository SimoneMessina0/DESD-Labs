library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity img_conv is
  generic (
    LOG2_N_COLS : positive := 8;
    LOG2_N_ROWS : positive := 8
  );
  port (

    clk     : in std_logic;
    aresetn : in std_logic;

    m_axis_tdata  : out std_logic_vector(7 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in std_logic;
    m_axis_tlast  : out std_logic;

    conv_addr : out std_logic_vector(LOG2_N_COLS + LOG2_N_ROWS - 1 downto 0);
    conv_data : in std_logic_vector(6 downto 0);

    start_conv : in std_logic;
    done_conv  : out std_logic

  );
end entity img_conv;

architecture rtl of img_conv is

  constant ROWS : integer := 2 ** LOG2_N_ROWS;
  constant COLS : integer := 2 ** LOG2_N_COLS;

  -- Convolution Matrix type and initialization
  type conv_mat_type is array(0 to 2, 0 to 2) of integer;
  constant conv_mat : conv_mat_type := ((-1, -1, -1), (-1, 8, -1), (-1, -1, -1));

  -- Convolution Signals definition
  signal row_kernel : integer range -1 to 1 := - 1;
  signal col_kernel : integer range -1 to 1 := - 1;

  signal row_index : integer range 0 to 2 ** LOG2_N_ROWS - 1 := 0;
  signal col_index : integer range 0 to 2 ** LOG2_N_COLS - 1 := 0;

  signal conv_pix : integer range -1024 to 1023 := 0;
  signal conv_sum : integer range -1024 to 1023 := 0;

  -- AXI Signals definition
  signal valid_reg : std_logic := '0';
  signal last_reg  : std_logic := '0';

  --FSM Signals
  --WAITING: Waiting for the start signal to begin the convolution
  --SEND_ADDRESS: Calculating the address of the pixel to be read from BRAM
  --RECEIVE:  Waits one cycle for BRAM to provide data, then applies the convolution
  --CONVOLVE:Adds the weighted pixel value to the accumulator (conv_sum). Advances kernel position, or moves to OUTPUT when kernel is done.
  --OUTPUT: applies saturation if needed, sets output signals, and prepares for AXI handshake.
  --WAIT_HANDSHAKE: Waits for m_axis_tready. Advances image pixel index or ends convolution.
  type fsm_type is (WAITING, SEND_ADDRESS, RECEIVE, CONVOLVE, OUTPUT, WAIT_HANDSHAKE);
  signal conv_state : fsm_type := WAITING;

  -- Flag to indicate if the current kernel address is within image bounds
  signal valid_address : std_logic := '0';

  -- Used to insert a wait cycle before retrieving the pixel from BRAM
  signal stall         : std_logic := '0'; 

begin

  m_axis_tvalid <= valid_reg;
  m_axis_tlast  <= last_reg;

  process (clk, aresetn)
  begin
    if aresetn = '0' then
      valid_reg  <= '0';
      last_reg   <= '0';
      conv_sum   <= 0;
      conv_state <= WAITING;
      done_conv  <= '0';
    elsif rising_edge(clk) then
      case conv_state is
        
        -- Waiting for the start signal to begin the convolution
        -- and reset the indexes
        
        when WAITING =>
          if start_conv = '1' then
            conv_state <= SEND_ADDRESS;
            last_reg   <= '0';
            row_index <= 0;
            col_index <= 0;
          end if;
          valid_reg <= '0';
          done_conv  <= '0';


        -- Calculating the address of the pixel to be read from BRAM
        when SEND_ADDRESS =>
          -- Check if the kernel address is within image boundaries
          -- Eventually compute the BRAM address to retrieve the requested pixel
          if ((row_index + row_kernel) >= 0 and (row_index + row_kernel) < ROWS) and ((col_index + col_kernel) >= 0 and (col_index + col_kernel) < COLS) then
            conv_addr     <= std_logic_vector(to_unsigned((row_index + row_kernel) * COLS + (col_index + col_kernel), conv_addr'LENGTH));
            --The address calculated is valid, so the data from BRAM is available
            valid_address <= '1';
          else
            valid_address <= '0';
          end if;

          valid_reg  <= '0';
          conv_state <= RECEIVE;
        


        -- Receiving the data from BRAM and calculating the convolution 
        when RECEIVE =>
          if stall = '1' then
            if valid_address = '1' then
              -- To avoid negative slack, data receiving and convolution are executed on two different states
              conv_pix <= to_integer(unsigned(conv_data)) * conv_mat(row_kernel + 1, col_kernel + 1);
            end if;
            stall      <= '0';
            conv_state <= CONVOLVE;
          elsif stall = '0'then
            stall <= '1';
          end if;


        -- Convolution sum calculation
        when CONVOLVE =>
          -- Accumulate the weighted pixel value only if within bounds and the address is valid'
          if valid_address = '1' then
            conv_sum <= conv_sum + conv_pix;
          end if;
          
          if col_kernel = 1 then
            -- After the convolution window is completed, move to the output state
            if row_kernel = 1 then
              conv_state <= OUTPUT;
              row_kernel <= - 1;
              col_kernel <= - 1;
            -- The kernel indexes are updated
            else
              row_kernel <= row_kernel + 1;
              col_kernel <= - 1;
              conv_state <= SEND_ADDRESS;
            end if;
          else
            col_kernel <= col_kernel + 1;
            conv_state <= SEND_ADDRESS;
          end if;

        -- Output the convolution result
        when OUTPUT =>
          -- if the sum is <0, output is set to 0
          -- if the sum is >127, output is set to 127
          -- else the output is set to the sum
          if conv_sum < 0 then
            m_axis_tdata <= (others => '0');
          elsif conv_sum > 127 then
            m_axis_tdata <= std_logic_vector(to_unsigned(127, m_axis_tdata'LENGTH));
          else
            m_axis_tdata <= std_logic_vector(to_unsigned(conv_sum, m_axis_tdata'LENGTH));
          end if;
          
          -- If the image is at the end, last_reg is set to 1
          -- else it is set to 0  
          if (row_index = ROWS - 1) and (col_index = COLS - 1) then
            last_reg <= '1';
          else
            last_reg <= '0';
          end if;

          -- valid_reg is set to 1 and the data is sent
          -- and move to the WAIT_HANDSHAKE state
          valid_reg  <= '1';
          conv_state <= WAIT_HANDSHAKE;
          conv_sum   <= 0;


        -- Wait for AXI master to accept the data (m_axis_tready = '1')
        -- Advance to next pixel or signal the end of convolution
        when WAIT_HANDSHAKE =>
          if m_axis_tready = '1' then
            valid_reg <= '0';
            
            -- If the computed pixel is the last, move to the WAITING state 
            -- and done_conv signal is sent
            
            if (row_index = ROWS - 1) and (col_index = COLS - 1) then
              done_conv  <= '1';
              conv_state <= WAITING;
            else
              -- If the computed pixel is not the last, advance to the next pixel
              -- The pixel indexes are updated
              if col_index = COLS - 1 then
                row_index <= row_index + 1;
                col_index <= 0;
              else
                col_index <= col_index + 1;
              end if;
              conv_state <= SEND_ADDRESS;
            end if;
          end if;

      end case;
    end if;
  end process;

end architecture;
