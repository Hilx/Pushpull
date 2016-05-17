LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_delete_all IS
  PORT(
    clk       : IN  STD_LOGIC;
    rst       : IN  STD_LOGIC;
    start     : IN  STD_LOGIC;
    done      : OUT STD_LOGIC;
    alloc_in  : IN  allocator_com_type;
    alloc_out : OUT allocator_com_type;
    mcin      : IN  mem_control_type;
    mcout     : OUT mem_control_type
    );
END ENTITY dsl_delete_all;

ARCHITECTURE syn_dsl_delete_or_lookup OF dsl_delete_or_lookup IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate             : da_state_type;
  SIGNAL hdBucket, nowPtr, nextPtr : slv(31 DOWNTO 0);
  SIGNAL flag_last                 : STD_LOGIC;
  SIGNAL entry_count               : INTEGER;
BEGIN
  da_comb : PROCESS(state, start, alloc_in, mcin,
                    hdBucket, flag_last, nowPtr)
  BEGIN
    nstate <= idle;                     -- default
    CASE state IS
      WHEN idle =>
        nstate <= idle;
        IF start = '1' THEN
          nstate <= rbucket;
        END IF;
      WHEN rbucket =>
        nstate <= rbucket_wait;
      WHEN rbucket_wait =>
        nstate <= rbucket_wait;
        IF mcin.done = '1' THEN
          nstate <= rbucket_check;
        END IF;
      WHEN rbucket_check =>
        nstate <= read_np;
        IF hdBucket = nullPtr THEN
          nstate <= rbucket;
        ELSIF flag_last = '1' THEN
          nstate <= isdone;
        END IF;
      WHEN read_np =>
        nstate <= read_np_wait;
        IF nowPtr = nullPtr THEN
          nstate <= rbucket;
        END IF;
      WHEN read_np_wait =>
        nstate <= read_np_wait;
        IF mcin.done = '1' THEN
          nstate <= free_node;
        END IF;
      WHEN free_node =>
        nstate <= free_node_wait;
      WHEN free_node_wait =>
        nstate <= free_node_wait;
        IF alloc_in.done = '1' THEN
          nstate <= read_np;
        END IF;
      WHEN isdone =>
        nstate <= idle;
      WHEN OTHERS => nstate <= idle;
    END CASE;
  END PROCESS;

  da_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state           <= nstate;
    alloc_out.start <= '0';
    mcout.start     <= '0';
    done            <= '0';
    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          flag_last     <= '0';
          entry_count   <= 0;
          alloc_out.cmd <= free;
          mcout.cmd     <= mread;
        WHEN rbucket =>
          -- mem interaction
          mcout.addr  <= slv(uns(MEM_BASE) + (entry_count SLL ADDR_WORD_OFF_BIN));
          mcout.start <= '1';
          -- internal fsm control
          entry_count <= entry_count + 1;
          IF entry_count = (TOTAL_HASH_ENTRY - 2) THEN
            flag_last <= '1';
          END IF;
        WHEN rbucket_check =>
          hdBucket <= mcin.rdata;
          nowPtr   <= mcin.rdata;
        WHEN read_np =>
          mcout.addr  <= slv(uns(nowPtr));
          mcout.start <= '1';
        WHEN free_node =>
          nextPtr         <= mcin.rdata;
          -- free
          alloc_out.start <= '1';
          alloc_out.ptr   <= nowPtr;
        WHEN free_node_wait =>          -- IS IT SAFE TO UPDATE NOWPTR NOW?
          nowPtr <= nextPtr; -- make sure pointer to be freed remain valid
        WHEN isdone =>
	  done <= '1';
        WHEN OTHERS => NULL;
      END CASE;

    END IF;  -- reset stuff
    
  END PROCESS;

END ARCHITECTURE;
