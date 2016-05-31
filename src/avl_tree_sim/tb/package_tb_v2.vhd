LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;

PACKAGE tb_pack_v2 IS
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
    (0, "000", x"00000000", x"00000000", '0'),  -- init malloc
    -- insert
    (1, "100", x"00000007", x"00000000", '0'),
    (2, "100", x"00000004", x"11110000", '0'),
    (3, "100", x"0000000A", x"22220000", '0'),
    (4, "100", x"00000005", x"33330000", '0'),
    (5, "100", x"00000009", x"44440000", '0'),
    (6, "100", x"0000000B", x"55550000", '0'),
    (7, "100", x"00000008", x"55550000", '0'),

    -- lookup
   -- (7, "110", x"00000002", x"00000000", '0'),
   -- (8, "110", x"00000005", x"00000000", '0'),
   -- (9, "110", x"00000013", x"00000000", '0'),
   -- (10, "110", x"00000007", x"00000000", '0'),
    -- delete
      
      (8, "101", x"00000005", x"00000000", '0'),
        (9, "101", x"00000009", x"00000000", '0'),   
    -- delete all
    --(11, "111", x"00000007", x"00000000", '0'),
    -- end of test
    (10, "001", x"00000000", x"00000000", '1')
    );

END PACKAGE;
