LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;

PACKAGE tb_pack_v1 IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  -- configuration
  CONSTANT MAX_BRAM_ADDR : INTEGER := 511;

  TYPE tb_fsm_v0_type IS (idle, isdone,
                          ready, command, busy, check);

  TYPE tb_data_type IS RECORD
    index : INTEGER;
    cmd   : slv(2 DOWNTO 0);
    key   : slv(31 DOWNTO 0);
    data  : slv(31 DOWNTO 0);
    last  : STD_LOGIC;
  END RECORD;

  TYPE tb_data_array_type IS ARRAY (NATURAL RANGE <>) OF tb_data_type;

  -- test inputs
  CONSTANT myTest : tb_data_array_type := (
(0, "000", x"00000000", x"00000000",'0'),
(1, "000", x"00000000", x"00000000",'0')
    );

END PACKAGE;
