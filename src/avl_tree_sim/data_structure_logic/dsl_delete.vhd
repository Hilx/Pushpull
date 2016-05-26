LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;
USE work.dsl_pack_func.ALL;

ENTITY dsl_delete IS
  PORT(
    clk                : IN  STD_LOGIC;
    rst                : IN  STD_LOGIC;
    -- root
    rootPtr_IN         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    rootPtr_OUT        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- control
    start              : IN  STD_LOGIC;
    done               : OUT STD_LOGIC;
    -- item
    key                : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- node access
    node_request_port  : OUT node_access_comm_type;
    node_response_port : IN  node_access_comm_type;
    -- allocator
    alloc_in           : IN  allocator_com_type;
    alloc_out          : OUT allocator_com_type
    );
END ENTITY dsl_delete;

ARCHITECTURE syn_dsl_delete OF dsl_delete IS
  ALIAS uns IS UNSIGNED;
  
BEGIN


END ARCHITECTURE;
