LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsl_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  TYPE dsl_cmd_type IS(insert, delete, lookup, delete_all, init_hash);

  TYPE dsl_com_in_type IS RECORD
    key   : slv(31 DOWNTO 0);
    data  : slv(31 DOWNTO 0);
    cmd   : dsl_cmd_type;
    start : STD_LOGIC;
  END RECORD;

  TYPE dsl_com_out_type IS RECORD
    data : slv(31 DOWNTO 0);
    done : STD_LOGIC;
  END RECORD;

  TYPE dsl_overall_control_state_type IS (idle, start, busy, done);
  TYPE dsl_internal_control_type IS RECORD
    insert     : STD_LOGIC;
    delete     : STD_LOGIC;
    lookup     : STD_LOGIC;
    delete_all : STD_LOGIC;
    init_hash  : STD_LOGIC;
  END RECORD;

  TYPE hash_init_state_type IS (idle, wstart, wwait, compute, done);

END PACKAGE;
