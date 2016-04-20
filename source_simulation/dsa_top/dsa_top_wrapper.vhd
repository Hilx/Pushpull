LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.dsa_top_pack.ALL;
USE work.malloc_pack.ALL;               -- memory management package
USE work.dsl_pack.ALL;                  -- data structure logic package

ENTITY dsa_top_wrapper IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    mmu_init_bit  : IN  STD_LOGIC;         -- allocator initialisation command
    mmu_init_done : OUT STD_LOGIC;
    -- dsl communication
    request       : IN  slv(31 DOWNTO 0);  -- untranslated request input
    response      : OUT dsl_com_out_type;
    -- memory controller communciation
    tmc_in        : IN  dsa_top_mem_control_type;
    tmc_out       : OUT dsa_top_mem_control_type
    );
END ENTITY dsa_top_wrapper;

ARCHITECTURE syn_dsa_top_wrapper OF dsa_top_wrapper IS
BEGIN

END ARCHITECTURE syn_dsa_top_wrapper;

