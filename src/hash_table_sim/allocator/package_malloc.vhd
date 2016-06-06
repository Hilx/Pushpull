LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE malloc_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  -- allocator control

  TYPE allocator_cmd_type IS (malloc, free);
  TYPE hash_malloc_command_type IS (items, hash_entries);

  TYPE allocator_com_type IS RECORD
    start  : STD_LOGIC;
    cmd    : allocator_cmd_type;
    ptr    : slv(31 DOWNTO 0);
    done   : STD_LOGIC;
    istype : hash_malloc_command_type;
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

  -- allocator initialisation stuff  

  TYPE mmu_init_type IS RECORD
    start : STD_LOGIC;
    done  : STD_LOGIC;
  END RECORD;

  TYPE initialisation_state_type IS (init_state_idle,
                                     init_state_compute,
                                     init_state_write,
                                     init_state_wait,
                                     init_state_done,
                                     entry_compute,
                                     entry_write0,
                                     entry_write1);
END PACKAGE;
