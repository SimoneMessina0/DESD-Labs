library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity div3 is
  port (
    sum : in std_logic_vector(8 downto 0);

    div : out std_logic_vector(7 downto 0)
  );
end entity;

architecture Behavioral of div3 is

  signal long_div : unsigned(17 downto 0);
begin

  long_div <= unsigned(sum) * 43;
  div      <= std_logic_vector(long_div(14 downto 7));

  -- The" division by 3" operation is computed as a "multiplication by 1/3"
  -- To mimic this operation, the input number is multiplied by 43 and shifted by 7 bits;
  -- that's the same as multiplying by 43 and dividing by 128, so the number is
  -- multiplied by 0.3359375.
  -- In our scenario, the maximum input sum is 381, so the maximum long_div = 381*43=16383
  -- div = 16383>>7 = 127. The operation is correct and has no error at all on our range of interest.

end architecture;
