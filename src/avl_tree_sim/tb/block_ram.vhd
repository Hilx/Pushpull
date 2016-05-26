LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.tb_pack_v2.ALL;

ENTITY block_ram IS
  PORT(
    clk      : IN  STD_LOGIC;
    we       : IN  STD_LOGIC;
    address  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data_in  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY block_ram;

ARCHITECTURE behav_block_ram OF block_ram IS
  TYPE memory IS ARRAY(0 TO MAX_BRAM_ADDR) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL myram : memory;
-- ATTRIBUTE ram_init_file          : STRING;
-- ATTRIBUTE ram_init_file OF myram : SIGNAL IS "ram_data.hex";
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
  
END ARCHITECTURE behav_block_ram;
