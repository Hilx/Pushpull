LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;

PACKAGE tb_pack_v1 IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  -- configuration
  CONSTANT MAX_BRAM_ADDR : INTEGER := 1023;

  TYPE tb_fsm_v0_type IS (idle, isdone,
                          ready, command, busy, check);

  TYPE tb_data_type IS RECORD
    index    : INTEGER;
    cmd      : slv(2 DOWNTO 0);
    key      : slv(31 DOWNTO 0);
    data     : slv(31 DOWNTO 0);
    root_sel : INTEGER;
    last     : STD_LOGIC;
  END RECORD;

  TYPE tb_data_array_type IS ARRAY (NATURAL RANGE <>) OF tb_data_type;

  -- test inputs
  CONSTANT myTest : tb_data_array_type := (
    (0, "000", x"00000000", x"00000000", 0, '0'),
    --insert
    (1, "100", x"00000000", x"00000000", 0, '0'),
    (2, "100", x"00000001", x"11111111", 1, '0'),
    (3, "100", x"00000002", x"22222222", 2, '0'),
    (4, "100", x"00000003", x"33333333", 0, '0'),
    (5, "100", x"00000004", x"44444444", 1, '0'),
    (6, "100", x"00000005", x"55555555", 2, '0'),
    (7, "100", x"00000006", x"66666666", 0, '0'),
    -- lookup
    (8, "110", x"00000000", x"22000055", 0, '0'),
    (9, "110", x"00000000", x"22000055", 1, '0'),
    (10, "110", x"00000000", x"22000055", 2, '0'),
    (11, "110", x"00000001", x"22000055", 0, '0'),
    (12, "110", x"00000001", x"22000055", 1, '0'),
    (19, "110", x"00000001", x"22000055", 2, '0'),
    -- delete all
    --(13, "111", x"0000002B", x"22000055", 0, '0'),
    -- end of test
    (13, "001", x"00000000", x"00000000", 0, '1')
    );

END PACKAGE;
