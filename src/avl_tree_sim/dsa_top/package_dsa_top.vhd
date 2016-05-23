LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsa_top_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  -- memory access arbitrator fsm stuff
  TYPE maa_state_type IS(maa_state_ds, maa_state_alloc);

  -- FOR PURPOSE OF TESTING MALLOC FOR NOW, translator fsm stuff
  TYPE tra_state_type IS(tra_state_idle,
                         tra_state_start,
                         tra_state_wait,
                         tra_state_done);

  TYPE dsa_request_type IS RECORD
    cmd   : slv(2 DOWNTO 0);
    key   : slv(31 DOWNTO 0);
    data  : slv(31 DOWNTO 0);
    start : STD_LOGIC;
  END RECORD;

END PACKAGE;