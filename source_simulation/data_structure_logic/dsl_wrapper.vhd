LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_wrapper IS
  PORT(
    clk:std_logic;
    rst:std_logic;
    -- dsl communication
    dsl_in : IN dsl_com_in_type;
    dsl_out :OUT dsl_com_out_type;
    -- allocator communication
    alloc_in : IN allocator_com_type;
    alloc_out: OUT allocator_com_type;
    -- memory controller communication
    mcin :IN mem_control_type;
    mcout : OUT mem_control_type;
    );
END ENTITY dsl_wrapper;

ARCHITECTURE syn_dsl_wrapper OF dsl_wrapper IS
BEGIN

END ARCHITECTURE syn_dsl_wrapper;
