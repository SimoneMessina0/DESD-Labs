library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity moving_average_filter_en is
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
    m_axis_tready : in std_logic;

    enable_filter : in std_logic
  );
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is
  -- Output data signals
  signal data_out_filtered : std_logic_vector(s_axis_tdata'range);
  signal data_out_allpass  : std_logic_vector(s_axis_tdata'range);
  signal data_out          : std_logic_vector(s_axis_tdata'range);

  -- AXI control signals
  signal ready_reg_filtered : std_logic := '1';
  signal valid_reg_filtered : std_logic := '0';
  signal tlast_reg_filtered : std_logic := '0';

  signal ready_reg_allpass : std_logic := '1';
  signal valid_reg_allpass : std_logic := '0';
  signal tlast_reg_allpass : std_logic := '0';

  -- Control signals
  signal s_axis_tvalid_filtered : std_logic := '0';
  signal s_axis_tvalid_allpass  : std_logic := '0';
  signal m_axis_tready_filtered : std_logic := '0';
  signal m_axis_tready_allpass  : std_logic := '0';

  --Moving average filter module definition
  component moving_average_filter is
    generic (
      -- Filter order expressed as 2^(FILTER_ORDER_POWER)
      FILTER_ORDER_POWER : integer  := 5;
      TDATA_WIDTH        : positive := 24
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
  end component;

  --All pass average filter module definition
  component all_pass_filter is
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
      m_axis_tready : in std_logic
    );
  end component;

begin
  -- Route input data to the appropriate filter based on enable_filter
  s_axis_tvalid_filtered <= s_axis_tvalid when enable_filter = '1' else
    '0';
  s_axis_tvalid_allpass <= s_axis_tvalid when enable_filter = '0' else
    '0';

  -- Route output ready signal to the appropriate filter
  m_axis_tready_filtered <= m_axis_tready when enable_filter = '1' else
    '0';
  m_axis_tready_allpass <= m_axis_tready when enable_filter = '0' else
    '0';

  -- AXI signals multiplexing based on enable_filter
  s_axis_tready <= ready_reg_filtered when enable_filter = '1' else
    ready_reg_allpass;

  m_axis_tvalid <= valid_reg_filtered when enable_filter = '1' else
    valid_reg_allpass;

  m_axis_tlast <= tlast_reg_filtered when enable_filter = '1' else
    tlast_reg_allpass;

  m_axis_tdata <= data_out_filtered when enable_filter = '1' else
    data_out_allpass;

  --Moving Average Filter instance
  moving_average_filter_inst : moving_average_filter
  generic map(
    FILTER_ORDER_POWER => FILTER_ORDER_POWER,
    TDATA_WIDTH        => TDATA_WIDTH
  )
  port map
  (
    aclk    => aclk,
    aresetn => aresetn,

    s_axis_tvalid => s_axis_tvalid_filtered,
    s_axis_tdata  => s_axis_tdata,
    s_axis_tlast  => s_axis_tlast,
    s_axis_tready => ready_reg_filtered,

    m_axis_tvalid => valid_reg_filtered,
    m_axis_tdata  => data_out_filtered,
    m_axis_tlast  => tlast_reg_filtered,
    m_axis_tready => m_axis_tready_filtered
  );

  -- All Pass Filter instance
  all_pass_filter_inst : all_pass_filter
  generic map(
    TDATA_WIDTH => TDATA_WIDTH
  )
  port map
  (
    aclk    => aclk,
    aresetn => aresetn,

    s_axis_tvalid => s_axis_tvalid_allpass,
    s_axis_tdata  => s_axis_tdata,
    s_axis_tlast  => s_axis_tlast,
    s_axis_tready => ready_reg_allpass,

    m_axis_tvalid => valid_reg_allpass,
    m_axis_tdata  => data_out_allpass,
    m_axis_tlast  => tlast_reg_allpass,
    m_axis_tready => m_axis_tready_allpass
  );
end Behavioral;