LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;

ENTITY mmu_init_block IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    start         : IN  STD_LOGIC;
    done          : OUT STD_LOGIC;
    mcin          : IN  mem_control_type;
    mcout         : OUT mem_control_type;
    hash_mem_base : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY mmu_init_block;

ARCHITECTURE syn_mmu_init OF mmu_init_block IS
  ALIAS uns IS UNSIGNED;
  SIGNAL currentNodePtr          : slv(31 DOWNTO 0);
  SIGNAL init_state, init_nstate : initialisation_state_type;
  SIGNAL node_count              : INTEGER RANGE 0 TO LIST_LENGTH;
  SIGNAL table_count             : INTEGER RANGE 0 TO MAX_NUM_TABLES;
BEGIN
  
  init_fsm_comb : PROCESS(init_state, start, mcin, node_count, table_count)
  BEGIN

    CASE init_state IS
      WHEN init_state_idle =>
        init_nstate <= init_state_idle;
        IF start = '1' THEN
          init_nstate <= init_state_compute;
        END IF;
      WHEN init_state_compute =>
        init_nstate <= init_state_write;
      WHEN init_state_write =>
        init_nstate <= init_state_wait;
      WHEN init_state_wait =>
        init_nstate <= init_state_wait;
        IF mcin.done = '1' THEN
          init_nstate <= init_state_compute;
          IF node_count = LIST_LENGTH THEN
            -- init_nstate <= init_state_done;
            init_nstate <= entry_compute;
          END IF;
        END IF;
      WHEN entry_compute => init_nstate <= entry_write0;
      WHEN entry_write0  => init_nstate <= entry_write1;
      WHEN entry_write1  => init_nstate <= entry_write1;
                            IF mcin.done = '1' THEN
                              init_nstate <= entry_compute;
                              IF table_count = MAX_NUM_TABLES THEN
                                init_nstate <= init_state_done;
                              END IF;
                            END IF;
      WHEN init_state_done =>
        init_nstate <= init_state_idle;
      WHEN OTHERS =>
        init_nstate <= init_state_idle;
    END CASE;

  END PROCESS init_fsm_comb;

  init_fsm_reg : PROCESS
    VARIABLE nextNodePtr : slv(31 DOWNTO 0);
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    init_state  <= init_nstate;
    done        <= '0';
    mcout.start <= '0';

    IF rst = CONST_RESET THEN
      init_state <= init_state_idle;
    ELSE
      
      CASE init_state IS
        WHEN init_state_idle =>
          currentNodePtr <= slv(uns(MEM_BASE));
          node_count     <= 0;
          table_count    <= 0;
        WHEN init_state_compute =>
          nextNodePtr    := slv(uns(currentNodePtr) + uns(MEM_BLOCK_SIZE));
                                        -- mem conrtol code
          mcout.addr     <= currentNodePtr;
          mcout.wdata    <= nextNodePtr;
          mcout.cmd      <= mwrite;
                                        -- update currentNodePtr
          currentNodePtr <= nextNodePtr;
          IF node_count = (LIST_LENGTH - 1) THEN
            mcout.wdata <= nullPtr;
          END IF;
                                        -- increment node count
          node_count <= node_count + 1;
        WHEN init_state_write =>
          mcout.start <= '1';

        WHEN entry_compute =>
          IF table_count = 0 THEN
            hash_mem_base <= currentNodePtr;
          END IF;
          
          nextNodePtr := slv(uns(currentNodePtr)
                             +to_unsigned(TOTAL_HASH_ENTRY, 32));

          mcout.addr  <= currentNodePtr;
          mcout.wdata <= nextNodePtr;
          mcout.cmd   <= mwrite;

          currentNodePtr <= nextNodePtr;
          IF table_count = TOTAL_HASH_ENTRY -1 THEN
            mcout.wdata <= nullPtr;
          END IF;
          table_count <= table_count +1;
        WHEN entry_write0 =>
          mcout.start <= '1';
        WHEN init_state_done =>
          done <= '1';
        WHEN OTHERS => NULL;
      END CASE;
      
    END IF;  -- if reset
    
  END PROCESS;

END ARCHITECTURE syn_mmu_init;
