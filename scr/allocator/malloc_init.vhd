LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.malloc_pack.ALL;

ENTITY mmu_init IS
  PORT(
    clk    : IN  STD_LOGIC;
    rst    : IN  STD_LOGIC;
    start  : IN  STD_LOGIC;
    done   : OUT STD_LOGIC;
    input  : IN  mem_control_type;
    output : OUT mem_control_type
    );
END ENTITY mmu_init;

ARCHITECTURE syn_mmu_init OF mmu_init IS
  SIGNAL currentNodePtr          : slv(31 DOWNTO 0);
  SIGNAL init_state, init_nstate : initialisation_state;
  SIGNAL node_count              : INTEGER RANGE 0 TO LIST_LENGTH;
BEGIN
  
  init_fsm_comb : PROCESS(start, input, node_count)
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
        IF input.done = '1' THEN
          init_nstate <= init_state_compute;
          IF node_count = LIST_LENGTH THEN
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
    init_state   <= init_nstate;
    done         <= '0';
    output.start <= '0';

    IF rst = CONST_RESET THEN
      init_state <= init_state_idle;
    ELSE
      
      CASE init_state IS
        WHEN init_state_idle =>
          currentNodePtr <= MEM_BASE;
          node_count     <= 0;
        WHEN init_state_compute =>
          nextNodePtr    := slv(UNSIGNED(currentNodePtr) + UNSIGNED(MEM_BLOCK_SIZE));
          -- mem conrtol code
          output.addr    <= currentNodePtr;
          output.data    <= nextNodePtr;
          output.cmd     <= mc_write;
          -- update currentNodePtr
          currentNodePtr <= nextNodePtr;
          -- increment node count
          node_count     <= node_count + 1;
        WHEN init_state_write =>
          output.start <= '1';
        WHEN init_state_done =>
          done <= '1';
        WHEN OTHERS => NULL;
      END CASE;
      
    END IF;  -- if reset
    
  END PROCESS;

END ARCHITECTURE syn_mmu_init;
