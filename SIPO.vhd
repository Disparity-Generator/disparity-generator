library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! This component works like a serial input register, 
--! but the data is not output in parallel or serially in the usual way, 
--! but as the sum of all individual values.
entity SIPO_SUM is
  generic (
    G_REGISTER_WIDTH : integer := 5;
    G_INTEGER_RANGE  : integer := 99999
  );
  port (
    I_DATA    : in    integer range 0 to G_REGISTER_WIDTH * G_INTEGER_RANGE;
    I_RESET_N : in    std_logic;
    I_CLOCK   : in    std_logic;
    O_Q       : out   integer range 0 to G_REGISTER_WIDTH * G_INTEGER_RANGE
  );
end entity SIPO_SUM;

architecture BEHAVE of SIPO_SUM is

  type t_data_array is array (G_REGISTER_WIDTH - 1 downto 0) of integer range 0 to G_INTEGER_RANGE;

  signal r_q         : t_data_array;                                    -- Variable für lesen/ausgeben
  signal counter     : natural range 0 to G_REGISTER_WIDTH - 1 := 0;    -- Zähler für umschalten von reaI_DATA (RI_DATA)

begin

  PROC_SHIFT_AND_OUTPUT : process (I_CLOCK, I_RESET_N) is  -- Auf Clock oI_DATAer Clear reagieren

  begin

    if (I_RESET_N = '0') then -- Wenn Clear, Ausgang auf LOW resetten
    elsif (rising_edge(I_CLOCK)) then

      for i in G_REGISTER_WIDTH - 1 downto 1 loop

        r_q(i) <= r_q(i - 1);

      end loop;

      r_q(0) <= I_DATA;
    end if;

  end process PROC_SHIFT_AND_OUTPUT;

  -- taken from https://stackoverflow.com/a/15025355/9699530
  process (r_q) is

    variable sum : integer range 0 to G_REGISTER_WIDTH * G_INTEGER_RANGE;

  begin

    sum := 0;

    for i in G_REGISTER_WIDTH - 1 downto 0 loop

      sum := sum + r_q(i);

    end loop;

    O_Q <= sum;

  end process;

end architecture BEHAVE;
