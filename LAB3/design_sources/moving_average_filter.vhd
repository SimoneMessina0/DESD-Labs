library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity moving_average_filter is
  generic (
    -- Filter order expressed as 2^(FILTER_ORDER_POWER)
    FILTER_ORDER_POWER : integer := 5;

    TDATA_WIDTH : positive := 24
  );
  port (
    aclk    : in std_logic;
    aresetn : in std_logic;

    s_axis_tvalid : in std_logic;
    s_axis_tdata  : in std_logic_vector(TDATA_WIDTH - 1 downto 0);
    s_axis_tlast  : in std_logic;
    s_axis_tready : out std_logic;

    m_axis_tvalid : out std_logic;
    m_axis_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m_axis_tlast  : out std_logic;
    m_axis_tready : in std_logic
  );
end moving_average_filter;

architecture Behavioral of moving_average_filter is

  constant FIFO_LENGTH : integer := 2 ** FILTER_ORDER_POWER;

  -- FIFO type definition
  type FIFO_TYPE is array (FIFO_LENGTH - 1 downto 0) of std_logic_vector(s_axis_tdata'range);
  -- FIFO signals declaration
  signal FIFO_RIGHT : FIFO_TYPE := (others => (others => '0'));
  signal FIFO_LEFT  : FIFO_TYPE := (others => (others => '0'));

  -- Output Auxiliary signal
  signal data : std_logic_vector(s_axis_tdata'range) := (others => '0');

  --Global AXI signals
  signal ready_reg : std_logic := '1';
  signal valid_reg : std_logic := '0';
  signal last_reg  : std_logic := '0';

begin

  --Axi signals assignation (for code readability)
  s_axis_tready <= ready_reg;
  m_axis_tvalid <= valid_reg;
  m_axis_tlast  <= last_reg;
  m_axis_tdata  <= data;

  process (aclk, aresetn)
    --These variables are used to keep the sums of the FIFOs
    variable fifo_sum_left  : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 downto 0) := (others => '0');
    variable fifo_sum_right : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 downto 0) := (others => '0');
  begin
    if aresetn = '0' then
      -- Reset AXIs signals
      valid_reg <= '0';
      data      <= (others => '0');
      last_reg  <= '0';
      ready_reg <= '1';
      -- Reset FIFOs
      FIFO_LEFT  <= (others => (others => '0'));
      FIFO_RIGHT <= (others => (others => '0'));

      -- Reset sums
      fifo_sum_left  := (others => '0');
      fifo_sum_right := (others => '0');
    elsif rising_edge(aclk) then
      --Checking if the AXI Handshake has happened and if the receiver is ready again
      if valid_reg = '1' and m_axis_tready = '1' then
        valid_reg <= '0';
        ready_reg <= '1';
      end if;

      --Checking if the AXI data is valid and the receiver is ready after a succesful Handshake
      if s_axis_tvalid = '1' and ready_reg = '1' then

        valid_reg <= '1';
        ready_reg <= '0';
        last_reg  <= s_axis_tlast;
        if s_axis_tlast = '1' then
          --Right Channel Average Computing
          fifo_sum_right := fifo_sum_right - signed(FIFO_RIGHT(FIFO_RIGHT'HIGH));
          fifo_sum_right := fifo_sum_right + signed(s_axis_tdata);

          --Right FIFO management
          for I in (FIFO_LENGTH - 2) downto 0 loop
            FIFO_RIGHT (I + 1) <= FIFO_RIGHT(I);
          end loop;
          FIFO_RIGHT(0) <= s_axis_tdata;

          --Right Channel Output assignation
          data <= std_logic_vector(fifo_sum_right(fifo_sum_right'HIGH downto FILTER_ORDER_POWER));
        elsif s_axis_tlast = '0' then

          --Left Channel Average Computing
          fifo_sum_left := fifo_sum_left - signed(FIFO_LEFT(FIFO_LEFT'HIGH));
          fifo_sum_left := fifo_sum_left + signed(s_axis_tdata);
          --Left FIFO management
          for I in (FIFO_LENGTH - 2) downto 0 loop
            FIFO_LEFT (I + 1) <= FIFO_LEFT(I);
          end loop;
          FIFO_LEFT(0) <= s_axis_tdata;
          --Left Channel Output assignation
          data <= std_logic_vector(fifo_sum_left(fifo_sum_left'HIGH downto FILTER_ORDER_POWER));
        end if;
      end if;
    end if;
  end process;

end Behavioral;
