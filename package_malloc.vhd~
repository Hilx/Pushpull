LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE malloc_pack IS

  CONSTANT CONST_RESET : STD_LOGIC := '1';  -- depends on if active high

  ALIAS slv IS STD_LOGIC_VECTOR;

  -- CONFIGURATION CONSTANTS
  CONSTANT MEM_BASE       : slv(31 DOWNTO 0) := x"10000000";
  CONSTANT MEM_BLOCK_SIZE : slv(31 DOWNTO 0) := x"00000010";  -- 16B
  CONSTANT LIST_LENGTH    : INTEGER          := 16384;  -- total mem = 16384*16B

  TYPE mmu_init_type IS RECORD
    start : STD_LOGIC;
    done  : STD_LOGIC;
  END RECORD;

  -- allocator control
  TYPE allocator_cmd_type IS (malloc, free);
  TYPE allocator_com_type IS RECORD
    start : STD_LOGIC;
    cmd   : allocator_cmd_type;
    ptr   : slv(31 DOWNTO 0);
    done  : STD_LOGIC;
  END RECORD;

  -- allocator FSM
  TYPE allocator_state_type IS (mmu_state_idle,
                                mmu_state_malloc,
                                mmu_state_read_wait,
                                mmu_state_free,
                                mmu_state_write_wait,
                                mmu_state_done,
                                -- to initialise allocator list of mem blocks
                                mmu_state_init,
                                mmu_state_init_wait);

  -- memory control
  TYPE mem_control_cmd_type IS (mc_write, mc_read);
  TYPE mem_control_type IS RECORD
    start : STD_LOGIC;
    done  : STD_LOGIC;
    addr  : slv(31 DOWNTO 0);
    data  : slv(31 DOWNTO 0);
    cmd   : mem_control_cmd_type;
  END RECORD;

  -- malloc initialisation
  TYPE initialisation_state IS (init_state_idle,
                                init_state_compute,
                                init_state_write,
                                init_state_wait,
                                init_state_done);

END PACKAGE;
