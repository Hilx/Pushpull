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
    cmd           : IN  dsl_com_type;
    done          : OUT STD_LOGIC;
    lookup_result : OUT dsl_lookup_result_type;  -- data and if data is valid
    -- node access
    node_request  : OUT node_access_control_type;
    node_response : IN  node_access_control_type;
    --
    alloc_in      : IN  allocator_com_type;
    alloc_out     : OUT allocator_com_type;
    --
    mcin          : IN  mem_control_type;
    mcout         : OUT mem_control_type
    );
END ENTITY dsl_ild;

ARCHITECTURE syn_dsl_ild OF dsl_ild IS
  SIGNAL ild_state, ild_nstate : dsl_ild_state_type;
BEGIN
  ild_fsm_comb : PROCESS(ild_state, start, cmd, mcin, alloc_in)
  BEGIN
    ild_nstate <= idle;                 -- default state
    CASE ild_state IS
      WHEN idle =>
        ild_nstate <= idle;
        IF start = '1' THEN
          ild_nstate <= hashing;
        END IF;
      WHEN hashing =>
        ild_nstate <= rnode_start;
      -- --------------------
      -- READ NODE
      WHEN rnode_start =>
        ild_nstate <= rnode_wait;
      WHEN rnode_wait =>
        ild_nstate <= rnode_wait;
        IF mcin.done = '1' THEN
          ild_nstate <= rnode_valid;
        END IF;
      WHEN rnode_valid =>
        ild_nstate <= compare;
      -- --------------------
      -- COMPARISON
      WHEN compare =>
        ild_nstate <= rnode_start;      -- if smaller
        -- other cases
        IF cmd = lookup THEN
          IF equal OR large OR nullptr THEN
            ild_nstate <= isdone;
          END IF;
        ELSIF cmd = insert THEN
          IF equal THEN
            ild_nstate <= isdone;
          ELSIF larger OR nullptr THEN
            ild_nstate <= insertion;
          END IF;
        ELSIF cmd = delete THEN
          IF larger OR nullptr THEN
            ild_nstate <= isdone;
          ELSIF equal THEN
            ild_nstate <= deletion;
          END IF;
        END IF;
      -- --------------------
      WHEN isdone =>
        ild_nstate <= isdone;
      WHEN insertion =>
        ild_nstate <= isdone;           -- for now
      WHEN deletion =>
        ild_nstate <= isdone;           -- for now
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  ild_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

    ild_state       <= ild_nstate;
    done            <= '0';
    alloc_out.start <= '0';
    mcout.start     <= '0';

    IF rst = CONST_RESET THEN
      ild_state <= idle;
    ELSE
      CASE ild_state IS
        WHEN hashing =>
        -- how to hash?
        WHEN isdone =>
          done <= '1';
        WHEN rnode_start =>
          mcout.start <= '1';
        WHEN rnode_valid =>
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset

  END PROCESS;

END ARCHITECTURE;



