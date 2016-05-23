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
    (0, "000", x"00000000", x"00000000", '0'),
    (1, "001", x"00000000", x"00000000", '0'),
    -- insert
    (2, "100", x"00000023", x"33330013", '0'),
    (3, "100", x"00000013", x"44440013", '0'),
    (4, "100", x"0000002B", x"22220013", '0'),
    (5, "100", x"00000013", x"22220013", '0'),
    (6, "100", x"0000003B", x"11110013", '0'),
    (7, "100", x"00000003", x"55550013", '0'),
    -- delete
    (8, "101", x"0000003B", x"00000000", '0'),
    (9, "101", x"00000023", x"00000000", '0'),
    (10, "101", x"00000003", x"00000000", '0'),
    (11, "101", x"00000004", x"00000000", '0'),
    (12, "101", x"00000023", x"00000000", '0'),
    -- insert
    (13, "100", x"00000037", x"22000055", '0'),
    (14, "100", x"00000027", x"22000055", '0'),
    (15, "100", x"00000007", x"22000055", '0'),
    -- lookup
    (16, "110", x"00000047", x"22000055", '0'),
    (17, "110", x"00000023", x"22000055", '0'),
    (18, "110", x"00000007", x"22000055", '0'),
    (19, "110", x"0000002B", x"22000055", '0'),
    -- delete all
    (20, "111", x"0000002B", x"22000055", '0'),
    -- end of test
    (21, "001", x"00000000", x"00000000", '1')
    );

END PACKAGE;
