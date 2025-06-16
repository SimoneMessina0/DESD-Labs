library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity led_blinker is
  generic (
    CLK_PERIOD_NS   : positive := 10;
    BLINK_PERIOD_MS : positive := 1000;
    N_BLINKS        : positive := 4
  );
  port (
    clk         : in std_logic;
    aresetn     : in std_logic;
    start_blink : in std_logic;
    led         : out std_logic
  );
end entity;

architecture rtl of led_blinker is

  -- To round up the clock cycles ( if clk_period_ns is not a common divisor of 1000) we divide and multiply by clk_period_ns
  constant rounded_cycles : integer := 1000/CLK_PERIOD_NS * CLK_PERIOD_NS;

  type phase_type is (waiting, blinking, resting);
  signal time_ms         : positive range 0 to BLINK_PERIOD_MS := 0;
  signal time_us         : positive range 0 to 1000            := 0;
  signal time_ns         : positive range 0 to rounded_cycles  := 0;
  signal phase           : phase_type                          := waiting;
  signal blink_remaining : integer range 0 to N_BLINKS;

begin

  process (clk, aresetn)
  begin
    -- asyncronous reset
    if aresetn = '0' then
      led     <= '0';
      time_ms <= 0;
      phase   <= waiting;
    elsif rising_edge(clk) then
      -- The blinking mechanism consist of three phases:
      -- Phase 0: the LED is on until the ON TIME has passed (time_ms = BLINK_PERIOD_MS - CLK_PERIOD_NS)
      -- Phase 1: the LED is off until the OFF time has passed (time_ms rewind until time_ms = CLK_PERIOD_NS)
      -- Phase 2: N_BLINKS done, the blinker waits for a new start signal

      --The blinker starts in phase 2:
      --checking for start signal
      case (phase) is
        when waiting =>
          if start_blink = '1' then
            phase <= blinking;
          else
            led <= '0';
          end if;
          blink_remaining <= N_BLINKS;
          time_ms         <= 0;

        when blinking =>
          led     <= '1';
          time_ns <= time_ns + CLK_PERIOD_NS;
          if time_ns = rounded_cycles - CLK_PERIOD_NS then
            time_ns <= 0;
            time_us <= time_us + 1;
            if time_us = 1000 - 1 then
              time_us <= 0;
              time_ms <= time_ms + 1;
              if time_ms = BLINK_PERIOD_MS then
                time_ms <= 0;
                if blink_remaining = 1 then
                  phase <= waiting;
                else
                  blink_remaining <= blink_remaining - 1;
                  phase           <= resting;
                end if;
              end if;
            end if;
          end if;

        when resting =>
          led     <= '0';
          time_ns <= time_ns + CLK_PERIOD_NS;
          if time_ns = rounded_cycles - CLK_PERIOD_NS then
            time_ns <= 0;
            time_us <= time_us + 1;
            if time_us = 1000 - 1 then
              time_us <= 0;
              time_ms <= time_ms + 1;
              if time_ms = BLINK_PERIOD_MS then
                time_ms <= 0;
                phase   <= blinking;
              end if;
            end if;
          end if;

      end case;
    end if;
  end process;
end architecture;
