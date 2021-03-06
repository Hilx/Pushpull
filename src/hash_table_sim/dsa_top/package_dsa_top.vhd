LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsa_top_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  -- memory access arbitrator fsm stuff
  TYPE maa_state_type IS(maa_state_ds, maa_state_alloc);

  TYPE dsa_request_type IS RECORD
    cmd      : slv(2 DOWNTO 0);
    key      : slv(31 DOWNTO 0);
    data     : slv(31 DOWNTO 0);
    start    : STD_LOGIC;
    root_sel : INTEGER;
  END RECORD;

  -- roots stuff
  TYPE roots_update_state_type IS(idle, read_new, busy, new_in, write_out,
                                  check_root, create_new, create_busy, create_done,
                                  start_dsl,
                                  isdone,
                                  init_start, init_w0, init_w1, init_w2, init_au);
  CONSTANT MAX_ROOTS_RAM_ADDR  : INTEGER := 31;
  CONSTANT ROOTS_RAM_ADDR_BITS : INTEGER := 5;
END PACKAGE;
