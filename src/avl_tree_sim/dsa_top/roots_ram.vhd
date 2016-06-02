LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.dsa_top_pack.ALL;

ENTITY roots_ram IS
  PORT(
    clk      : IN  STD_LOGIC;
    we       : IN  STD_LOGIC;
    address  : IN  STD_LOGIC_VECTOR(ROOTS_RAM_ADDR_BITS-1 DOWNTO 0);
    data_in  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY roots_ram;

ARCHITECTURE behav_roots_ram OF roots_ram IS
  ALIAS slv IS STD_LOGIC_VECTOR;
  TYPE mem_type IS ARRAY(0 TO MAX_ROOTS_RAM_ADDR) OF slv(31 DOWNTO 0);
  SIGNAL myram : mem_type;
BEGIN
  PROCESS(clk)
  BEGIN
    IF (clk'event AND clk = '1') THEN
      IF (we = '1') THEN
        myram(to_integer(UNSIGNED(address))) <= data_in;
      END IF;
    END IF;
  END PROCESS;
  data_out <= myram(to_integer(UNSIGNED(address)));
END ARCHITECTURE behav_roots_ram;
