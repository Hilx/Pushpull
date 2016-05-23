LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_ild IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    --
    start         : IN  STD_LOGIC;
    cmd           : IN  dsl_cmd_type;
    done          : OUT STD_LOGIC;
    key           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    lookup_result : OUT dsl_lookup_result_type;  -- data and if data is valid
    -- node access
    node_request  : OUT node_access_comm_type;
    node_response : IN  node_access_comm_type;
    --
    alloc_in      : IN  allocator_com_type;
    alloc_out     : OUT allocator_com_type;
    --
    mcin          : IN  mem_control_type;
    mcout         : OUT mem_control_type
    );
END ENTITY dsl_ild;

ARCHITECTURE syn_dsl_ild OF dsl_ild IS
BEGIN
  ild_fsm_comb : PROCESS()
  BEGIN


  END PROCESS;

  ild_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

    IF rst = CONST_RESET THEN

    ELSE

    END IF;  -- if reset

  END PROCESS;

END ARCHITECTURE;



