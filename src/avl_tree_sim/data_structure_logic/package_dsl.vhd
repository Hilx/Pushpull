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
    insert     : STD_LOGIC;
    lookup     : STD_LOGIC;
    delete     : STD_LOGIC;
    delete_all : STD_LOGIC;
  END RECORD;

  TYPE dsl_lookup_result_type IS RECORD
    data  : slv(31 DOWNTO 0);
    found : STD_LOGIC;                  -- 0, not found; 1, found
  END RECORD;

  TYPE tree_node_type IS RECORD
    ptr      : slv(31 DOWNTO 0);
    key      : slv(31 DOWNTO 0);
    data     : slv(31 DOWNTO 0);
    leftPtr  : slv(31 DOWNTO 0);
    rightPtr : slv(31 DOWNTO 0);
    height   : INTEGER;
  END RECORD;

  TYPE node_access_cmd_type IS (rnode, wnode);

  TYPE node_access_comm_type IS RECORD
    cmd   : node_access_cmd_type;
    ptr   : slv(31 DOWNTO 0);
    node  : tree_node_type;
    start : STD_LOGIC;
    done  : STD_LOGIC;
  END RECORD;

  TYPE node_access_state_type IS(idle,
                                 r0start, r0wait,
                                 r1start, r1wait,
                                 r2start, r2wait,
                                 r3start, r3wait,
                                 r4start, r4wait,
                                 w0start, w0wait,
                                 w1start, w1wait,
                                 w2start, w2wait,
                                 w3start, w3wait,
                                 w4start, w4wait,
                                 done);


  -- INSERT
  TYPE insert_state_type IS (idle, checkroot,
                             rnode_start, rnode_wait, rnode_done,
                             alloc_start, alloc_wait, alloc_done,
                             wnew_start, wnew_wait, wnew_done,
                             comparekey,
                             balancing, write_stack,
                             isdone);

  TYPE insert_bal_state_type IS(idle,
                                ulink,
                                readchild_start,
                                readchild_wait,
                                cal_bal,
                                check_bal,
                                w_start, w_wait,
                                r1, r2, r3, r4, r5, r6, r7, r8, r9, r10,
                                l1, l2, l3, l4, l5, l6, l7, l8, l9, l10,
                                c_prep_wait, c_prep_sec, c_prep_wait2, c_prep_done,
                                d_prep_wait, d_prep_sec, d_prep_wait2, d_prep_done,
                                drcheck,
                                rotation_done,
                                read_stack,
                                isdone);

  TYPE lookup_state_type IS(idle,
                            checkroot,
                            rnode_start, rnode_wait, rnode_done,
                            comparekey,
                            isdone);

  TYPE delete_all_state_type IS(idle, checkroot,
                                rnode_start, rnode_wait, rnode_done,
                                free_start, free_wait, free_done,
                                check_node,
                                read_stack, update_node, write_stack,
                                isdone);

  TYPE balancing_case_type IS (A, B, C, D);
  TYPE missing_child_type IS(leftChild, rightChild);



  TYPE stack_type IS ARRAY (0 TO 31) OF tree_node_type;
  
END PACKAGE;

