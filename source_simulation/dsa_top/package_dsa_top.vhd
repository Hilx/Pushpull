LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsa_top_pack IS
  ALIAS slv IS std_logic_vector;

  TYPE dsa_top_mem_cmd_type IS (mwrite, mread);

  TYPE dsa_top_mem_control_type IS RECORD
    cmd        : dsa_top_mem_cmd_type;  -- for ddr
    write_data : slv(31 DOWNTO 0);
    read_data  : slv(31 DOWNTO 0);
    addr       : slv(31 DOWNTO 0);
    start      : STD_LOGIC;             -- write enable/for ddr
    done       : STD_LOGIC;
  END RECORD;

  -- memory access arbitrator fsm stuff
  TYPE maa_state_type is(maa_state_ds, maa_state_alloc);

  -- FOR PURPOSE OF TESTING MALLOC FOR NOW, translator fsm stuff
  TYPE tra_state_type is(tra_state_idle, tra_state_start, tra_state_wait, tra_state_done);

END PACKAGE;
