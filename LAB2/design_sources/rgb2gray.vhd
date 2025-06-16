library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

entity rgb2gray is
  port (
    clk    : in std_logic;
    resetn : in std_logic;

    m_axis_tvalid : out std_logic;
    m_axis_tdata  : out std_logic_vector(7 downto 0);
    m_axis_tready : in std_logic;
    m_axis_tlast  : out std_logic;

    s_axis_tvalid : in std_logic;
    s_axis_tdata  : in std_logic_vector(7 downto 0);
    s_axis_tready : out std_logic;
    s_axis_tlast  : in std_logic
  );
end rgb2gray;

architecture Behavioral of rgb2gray is

  component div3 is
    port (
      sum : in std_logic_vector(8 downto 0);
      div : out std_logic_vector(7 downto 0)
    );
  end component;

  type RGB_TYPE is array (0 to 2) of unsigned(7 downto 0); -- Per R, G, B
  signal ready_reg : std_logic            := '1';
  signal valid_reg : std_logic            := '0';
  signal last_reg  : std_logic            := '0';
  signal count     : integer range 0 to 2 := 0; -- 0=R, 1=G, 2=B
  signal holder    : RGB_TYPE             := (others => (others => '0'));
  signal sum       : unsigned(8 downto 0);

begin
  -- Division3 Module instance
  div3_inst : div3
  port map
  (
    sum => std_logic_vector(sum),
    div => m_axis_tdata
  );

  -- Signal Mapping
  s_axis_tready <= ready_reg;
  m_axis_tvalid <= valid_reg;
  m_axis_tlast  <= last_reg;

  -- Computing the sum of the RGB channels values
  sum <= "0" & (holder(0) + holder(1) + holder(2));

  clk_process : process (clk, resetn)
  begin
    -- Handling of the reset values
    -- The reset is active-low and the AXI interface is set on a "receiving" state
    if resetn = '0' then
      ready_reg <= '1';
      valid_reg <= '0';
      last_reg  <= '0';
      count     <= 0;
      holder    <= (others => (others => '0'));

    elsif rising_edge(clk) then
      -- Handling of the "output" stage. 
      if valid_reg = '1' and m_axis_tready = '1' then
        valid_reg <= '0';
        ready_reg <= '1';

      end if;
      -- Handling of the "data receiving" stage. AXI Handshake.
      if s_axis_tvalid = '1' and ready_reg = '1' then
        --Saving the RGB values
        holder(count) <= unsigned(s_axis_tdata);

        if count = 2 then -- RGB Packet receiving completed
          count     <= 0; -- Next byte will be from a new RGB Packet
          valid_reg <= '1'; -- Valid Output
          ready_reg <= '0'; -- Stop receiving Packets until output stage completed
          last_reg  <= s_axis_tlast; -- Forwarding the tlast flag to output
        else
          count <= count + 1; -- Next byte will be from the same RGB Packet
        end if;
      end if;
    end if;
  end process;

end Behavioral;