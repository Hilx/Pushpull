LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsl_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  TYPE dsl_cmd_type IS(insert, delete, lookup, delete_all);

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
    ild        : STD_LOGIC;
    delete_all : STD_LOGIC;
  END RECORD;

  TYPE hash_init_state_type IS (idle, wstart, wwait, compute, done);

  TYPE dsl_lookup_result_type IS RECORD
    data  : slv(31 DOWNTO 0);
    found : STD_LOGIC;                  -- 0, not found; 1, found
  END RECORD;

  TYPE dsl_ild_state_type IS ();

  TYPE tree_node_type IS RECORD
    ptr      : slv(31 DOWNTO 0);
    key      : slv(31 DOWNTO 0);
    data     : slv(31 DOWNTO 0);
    leftPtr  : slv(31 DOWNTO 0);
    rightPtr : slv(31 DOWNTO 0);
    height   : slv(31 DOWNTO 0);
  END RECORD;

  TYPE node_access_cmd_type IS (rnode, wnode);

  TYPE node_access_comm_type IS RECORD
    cmd   : node_access_cmd_type;
    ptr   : slv(31 DOWNTO 0);
    node  : hash_node_type;
    start : STD_LOGIC;
    done  : STD_LOGIC;
  END RECORD;

  TYPE node_access_state_type IS(idle,
                                 r0start, r0wait,
                                 r1start, r1wait,
                                 r2start, r2wait,
                                 w0start, w0wait,
                                 w1start, w1wait,
                                 w2start, w2wait,
                                 done);

  -- delete all
  TYPE da_state_type IS ();

END PACKAGE;
