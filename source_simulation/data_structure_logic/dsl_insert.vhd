LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_insert IS
  PORT(
    clk       : IN  STD_LOGIC;
    rst       : IN  STD_LOGIC;
    key       : IN  STD_LOGIC;
    data      : IN  STD_LOGIC;
    start     : IN  STD_LOGIC;
    done      : OUT STD_LOGIC;
    alloc_in  : IN  allocator_com_type;
    alloc_out : OUT allocator_com_type;
    mcin      : IN  mem_control_type;
    mcout     : OUT mem_control_type
    );
END ENTITY dsl_insert;

ARCHITECTURE syn_dsl_insert OF dsl_insert IS
BEGIN
  -- ---------------------------------------------
  -- ----------------- insert item ---------------
  -- ---------------------------------------------
  -- ---------------------------------------------
  insert_fsm_comb : PROCESS(start_bit, mcin)
  BEGIN

  END PROCESS;
  insert_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

  END PROCESS;
END ARCHITECTURE;
