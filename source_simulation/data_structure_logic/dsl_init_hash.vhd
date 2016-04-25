LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_init_hash IS
  PORT(
    clk         : IN  STD_LOGIC,
    rst         : IN  STD_LOGIC,
    total_entry : IN  STD_LOGIC_VECTOR,
    start_b     : IN  STD_LOGIC,
    done_b      : OUT STD_LOGIC,
    mcin        : IN  mem_control_type,
    mcout       : OUT mem_control_type
    );
END ENTITY dsl_init_hash;

ARCHITECTURE syn_dsl_init_hash OF dsl_init_hash IS
  SIGNAL init_state, init_nstate : hash_init_state_type;
  SIGNAL entry_count             : slv(31 DOWNTO 0);
  SIGNAL mem_addr                : slv(31 DOWNTO 0);
BEGIN
  -- ---------------------------------------------
  -- ---------- hash table initialisation --------
  -- -------- write nullPtr as hash entries ------
  -- ---------------------------------------------
  init_fsm_comb : PROCESS(start, init_state, mcin,
                          entry_count, total_entry)
  BEGIN
    init_nstate <= idle;
    CASE init_state IS
      WHEN idle =>
        init_nstate <= idle;
        IF start_b = '1' THEN
          init_nstate <= wstart;
        END IF;
      WHEN wstart =>
        init_nstate <= wwait;
      WHEN wwait =>
        init_nstate <= wwait;
        IF mcin.done = '1' THEN
          init_nstate <= compute;
        END IF;
      WHEN compute =>
        init_nstate <= wwrite;
        IF entry_count = total_entry THEN
          init_nstate <= done;
        END IF;
      WHEN done =>
        init_nstate <= idle;
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  mcout.addr <= mem_addr;
  init_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    init_state  <= init_nstate;
    mcout.start <= '0';
    done_b      <= '0';
    IF rst = CONST_RESET THEN
      init_state <= idle;
    ELSE
      CASE init_state IS
        WHEN idle =>
          mem_addr    <= MEM_BASE;
          mcout.wdata <= nullPtr;
          mcout.cmd   <= mwrite;
        WHEN wwrite =>
          mcout.start <= '1';
          node_count  <= slv(UNSIGNED(node_count) + 1);
        WHEN compute =>
          mem_addr <= slv(UNSIGNED(mem_addr) + ADDR_WORD_OFF_DEC);
        WHEN done =>
          done_b <= '1';
        WHEN OTHERS => NULL;
      END CASE;
    END IF;
  END PROCESS;

END ARCHITECTURE;
