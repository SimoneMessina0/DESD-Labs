library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity LFO is
    generic (
        CHANNEL_LENGHT            : integer := 24;
        JOYSTICK_LENGHT           : integer := 10;
        CLK_PERIOD_NS             : integer := 10;
        TRIANGULAR_COUNTER_LENGTH : integer := 10 -- Triangular wave period length
    );
    port (
        aclk    : in std_logic;
        aresetn : in std_logic;

        lfo_period : in std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);

        lfo_enable : in std_logic;

        s_axis_tvalid : in std_logic;
        s_axis_tdata  : in std_logic_vector(CHANNEL_LENGHT - 1 downto 0);
        s_axis_tlast  : in std_logic;
        s_axis_tready : out std_logic;

        m_axis_tvalid : out std_logic;
        m_axis_tdata  : out std_logic_vector(CHANNEL_LENGHT - 1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tready : in std_logic
    );
end entity;

architecture Behavioral of LFO is

    -- LFO Counter
    constant LFO_COUNTER_BASE_PERIOD_US     : integer := 1000;                                                -- Base period of the LFO counter in us (when the joystick is at the center)
    constant LFO_COUNTER_BASE_PERIOD_CYCLES : integer := (LFO_COUNTER_BASE_PERIOD_US * 1000) / CLK_PERIOD_NS; -- Conversion to ns and then to clock cycles
    constant ADJUSTMENT_FACTOR              : integer := 90;                                                  -- Multiplicative factor to scale the LFO period properly with the joystick y position

    signal lfo_period_steps  : integer range 0 to LFO_COUNTER_BASE_PERIOD_CYCLES := 0;                              -- LFO steps counter
    signal lfo_period_cycles : integer range 0 to LFO_COUNTER_BASE_PERIOD_CYCLES := LFO_COUNTER_BASE_PERIOD_CYCLES; -- Actual period of LFO in cycles
    signal subtract_cycles   : integer range 0 to LFO_COUNTER_BASE_PERIOD_CYCLES := 0;                              -- Actual period of LFO in cycles

    -- Amplitude of the Triangular wave 
    constant TRIANGULAR_COUNTER_MAX : integer := 2 ** TRIANGULAR_COUNTER_LENGTH;
    -- The triangular counter starts at its midpoint
    constant TRIANGULAR_COUNTER_MID : integer := TRIANGULAR_COUNTER_MAX / 2;

    -- UpDown Counter signals
    signal direction        : std_logic                                   := '1';
    signal triangular_steps : signed (TRIANGULAR_COUNTER_LENGTH downto 0) := to_signed(TRIANGULAR_COUNTER_MID, TRIANGULAR_COUNTER_LENGTH + 1);

    -- Output Auxiliary signals
    signal long_volume   : signed(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGTH downto 0) := (others => '0');
    signal actual_volume : std_logic_vector(s_axis_tdata'range)                        := (others => '0');

    --Global AXI signals
    signal ready_reg : std_logic := '1';
    signal valid_reg : std_logic := '0';
    signal last_reg  : std_logic := '0';
    -- Pipeline signal
    signal last_reg_pipeline  : std_logic := '0';

begin

    --Axi signals assignation (for code readability)
    s_axis_tready <= ready_reg;
    m_axis_tvalid <= valid_reg;
    m_axis_tlast  <= last_reg;
    m_axis_tdata  <= actual_volume;

    process (aclk, aresetn)
    begin
        if aresetn = '0' then
            -- Reset AXIs signals
            valid_reg     <= '0';
            ready_reg     <= '1';
            last_reg      <= '0';
            actual_volume <= (others => '0');
            -- Reset counter signals
            triangular_steps  <= to_signed(TRIANGULAR_COUNTER_MID, TRIANGULAR_COUNTER_LENGTH + 1); -- Reset to proper mid-point
            direction         <= '1';
            lfo_period_steps  <= 0;
            lfo_period_cycles <= LFO_COUNTER_BASE_PERIOD_CYCLES;
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
                last_reg_pipeline  <= s_axis_tlast;
                last_reg <= last_reg_pipeline;

                -- Output data logic: if the lfo_enable, output is modified accordingly, or else the input data is given to the output port
                if lfo_enable = '0' then
                    actual_volume <= s_axis_tdata;
                elsif lfo_enable = '1' then
                    -- The output volume is computed as a multiplication by the actual value
                    -- of the trianguar wave counter, and then the result is shifted by 10 bits
                    long_volume   <= signed(s_axis_tdata) * triangular_steps;
                    actual_volume <= std_logic_vector(resize(long_volume(long_volume'high downto TRIANGULAR_COUNTER_LENGTH), CHANNEL_LENGHT));
                end if;
            end if;
            -- lfo_period counter
            if lfo_enable = '1' then
                if lfo_period_steps < lfo_period_cycles then
                    lfo_period_steps <= lfo_period_steps + 1;
                else
                    --   triangular_steps updown counter based on lfo_period counter
                    if direction = '0' then
                        if triangular_steps < TRIANGULAR_COUNTER_MAX - 1 then
                            triangular_steps <= triangular_steps + 1;
                        else
                            direction <= '1';
                        end if;
                    else -- direction = '1'
                        if triangular_steps > 0 then
                            triangular_steps <= triangular_steps - 1;
                        else
                            direction <= '0';
                        end if;
                    end if;
                    subtract_cycles   <= ADJUSTMENT_FACTOR * to_integer(unsigned(lfo_period));
                    lfo_period_cycles <= LFO_COUNTER_BASE_PERIOD_CYCLES - subtract_cycles;
                    lfo_period_steps  <= 0;
                end if;
            end if;
        end if;
    end process;
end architecture;