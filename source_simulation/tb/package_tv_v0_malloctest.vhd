LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE tb_pack_v0 IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  TYPE tb_fsm_v0_type IS (idle,
                          init, initing,
                          ready, command, busy, check,
                          donestate);

  -- -------------------------------------
  -- ----- TESTING INPUT -----------------
  -- -------------------------------------  
  
  TYPE tb_data_type IS RECORD
    index : INTEGER;
    req   : slv(31 DOWNTO 0);
    last  : STD_LOGIC;
  END RECORD;

  TYPE tb_data_array_type IS ARRAY (NATURAL RANGE <>) OF tb_data_type;

  CONSTANT myTest : tb_data_array_type := (
    (0, x"00000000", '0'),
    (1, x"00000000", '0'),
    (2, x"00000000", '0'),
    (3, x"00000000", '0'),
    (4, x"00000000", '0'),
    (5, x"00000000", '0'),
    (6, x"00000000", '0'),
    (7, x"00000000", '0'),
    (8, x"00000000", '0'),
    (9, x"00000000", '0'),
    (10, x"00000000", '0'),
    (11, x"00000000", '0'),
    (12, x"00000000", '0'),
    (13, x"00000000", '0'),
    (14, x"00000001", '0'),
    (15, x"00000000", '0'),
    (16, x"11111111", '1')  -- INVALID INPUT, only signaling the tb to finish
    );

END PACKAGE;
