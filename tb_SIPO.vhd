library ieee;
use ieee.std_logic_1164.all;

ENTITY tb_SIPO IS -- keine Schnittstellen
END tb_SIPO ;


ARCHITECTURE testbench OF tb_SIPO IS
COMPONENT SIPO -- Komponentendeklaration fuer Device Under Test (DUT)
PORT (
		d: IN std_logic;
		clr: IN std_logic;
		clk: IN std_logic;
		q: OUT std_logic_vector(3 downto 0)
);
END COMPONENT ;


SIGNAL d : std_logic := '0'; -- Input Stimuli - Signale
SIGNAL clk : std_logic := '0';
SIGNAL clr : std_logic := '0';

SIGNAL q : std_logic_vector(3 downto 0); -- Output Signal

SIGNAL q_assert: std_logic_vector(3 downto 0); -- erwartetes Ausgangssignal
SIGNAL q_error: std_logic_vector(3 downto 0); -- Fehleranzeigesignal, TRUE bei Fehler

constant clk_period : time := 20 ns;

BEGIN
dut : SIPO -- Instantiieren des Device Under Test
PORT MAP ( 
	d => d,
	clk => clk,
	clr => clr,
	q => q
);

clk_process :process -- Prozess zur Taktgeneration
	begin             -- Jede halbe Periode wird die Clock invertiert
			clk <= '0';
		wait for clk_period/2;
			clk <= '1';
		wait for clk_period/2;
end process clk_process;

q_error <= NOT (q_assert XNOR q); -- Fehleranzeige erzeugen

d <= '1' AFTER 0 ns, '1' AFTER 20 ns, '0' AFTER 40 ns, '1' AFTER 60 ns, '1' AFTER 80 ns, '0' AFTER 100 ns, '1' AFTER 120 ns, '0' AFTER 140 ns;
q_assert <= "0000" AFTER 0 ns, "1011" AFTER 90 ns, "0101" AFTER 170 ns, "0000" AFTER 180 ns;
clr <= '0' AFTER 0 ns, '1' AFTER 180 ns;

END testbench ;