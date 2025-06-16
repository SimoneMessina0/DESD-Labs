library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity mute_controller is
  generic (
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
    m_axis_tready : in std_logic;

    mute : in std_logic
  );
end mute_controller;

architecture Behavioral of mute_controller is

  --Global AXI signals
  signal ready_reg : std_logic := '0';
  signal valid_reg : std_logic := '0';
  signal last_reg  : std_logic := '0';
begin

  --Axi signals assignation (for code readability)
  s_axis_tready <= ready_reg;
  m_axis_tvalid <= valid_reg;
  m_axis_tlast  <= last_reg;

  process (aclk, aresetn)
  begin
    if aresetn = '0' then
      -- Reset AXIs signals
      valid_reg    <= '0';
      ready_reg    <= '1';
      last_reg     <= '0';
      m_axis_tdata <= (others => '0');
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
        if mute = '0' then
          m_axis_tdata <= s_axis_tdata;
        else
          m_axis_tdata <= (others => '0');
        end if;
        last_reg <= s_axis_tlast;
      end if;
    end if;
  end process;

end Behavioral;
