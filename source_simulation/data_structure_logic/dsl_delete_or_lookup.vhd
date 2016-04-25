LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_delete_or_lookup IS
  PORT(
    clk       : IN  STD_LOGIC;
    rst       : IN  STD_LOGIC;
    cmd       : IN  STD_LOGIC;
    key       : IN  STD_LOGIC;
    start     : IN  STD_LOGIC;
    done      : OUT STD_LOGIC;
    alloc_in  : IN  allocator_com_type;
    alloc_out : OUT allocator_com_type;
    mcin      : IN  mem_control_type;
    mcout     : OUT mem_control_type
    );
END ENTITY dsl_delete_or_lookup;

ARCHITECTURE syn_dsl_delete_or_lookup OF dsl_delete_or_lookup IS
BEGIN

END ARCHITECTURE;
