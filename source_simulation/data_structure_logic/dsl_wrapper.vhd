LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_wrapper IS
  PORT(
    clk         : IN  STD_LOGIC;
    rst         : IN  STD_LOGIC;
    total_entry : IN  STD_LOGIC_VECTOR;
    -- dsl communication
    dsl_in      : IN  dsl_com_in_type;
    dsl_out     : OUT dsl_com_out_type;
    -- allocator communication
    alloc_in    : IN  allocator_com_type;
    alloc_out   : OUT allocator_com_type;
    -- memory controller communication
    mcin        : IN  mem_control_type;
    mcout       : OUT mem_control_type
    );
END ENTITY dsl_wrapper;

ARCHITECTURE syn_dsl_wrapper OF dsl_wrapper IS
  
  SIGNAL dsl_state, dsl_nstate   : dsl_overall_control_state_type;
  SIGNAL start_bit, done_bit     : dsl_internal_control_type;
  SIGNAL init_state, init_nstate : hash_init_state_type;
  SIGNAL entry_count             : slv(31 DOWNTO 0);
  SIGNAL mem_addr                : slv(31 DOWNTO 0);
  
BEGIN
  -- data structure logic
  dsl_fsm_comb : PROCESS(dsl_state, dsl_in, done_bit);
  BEGIN
    dsl_nstate <= idle;
    CASE dsl_state IS
      WHEN idle =>
        dsl_nstate <= idle;             -- default
        IF dsl_in.start = '1' THEN
          dsl_nstate <= start;
        END IF;
      WHEN start =>
        dsl_nstate <= busy;
      WHEN busy =>
        dsl_nstate <= busy;             -- default
        IF done_bit.insert = '1' OR done_bit.delete = '1'
          OR done_bit.lookup = '1' OR done_bit.delete_all = '1'
          OR done_bit.init_hash THEN
          dsl_nstate <= done;
        END IF;
      WHEN done =>
        dsl_nstate <= idle;
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  dsl_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    dsl_state            <= dsl_nstate;
    start_bit.insert     <= '0';
    start_bit.delete     <= '0';
    start_bit.lookup     <= '0';
    start_bit.delete_all <= '0';
    start_bit.init_hash  <= '0';
    dsl_out.done         <= '0';
    IF rst = CONST_RESET THEN
      dsl_state <= idle;
    ELSE
      IF dsl_state = start THEN
        CASE dsl_in.cmd IS
          WHEN start      => start_bit.insert     <= '1';
          WHEN delete     => start_bit.delete     <= '1';
          WHEN lookup     => start_bit.lookup     <= '1';
          WHEN delete_all => start_bit.delete_all <= '1';
          WHEN init_hash  => start_bit.init_hash  <= '1';
        END CASE;
      END IF;
      IF dsl_state = done THEN          -- feedback to outside
        dsl_out.done <= '1';            -- done bit
      -- --------------------------- REMEMBER TO ADD OTHER RESULT OUTPUT
      END IF;
    END IF;
  END PROCESS;

  -- ---------------------------------------------
  -- ---------- hash table initialisation --------
  -- -------- write nullPtr as hash entries ------
  -- ---------------------------------------------
  init_fsm_comb : PROCESS(start_bit, init_state, mcin,
                          entry_count, total_entry)
  BEGIN
    init_nstate <= idle;
    CASE init_state IS
      WHEN idle =>
        init_nstate <= idle;
        IF start_bit.hash_init = '1' THEN
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
    init_state         <= init_nstate;
    mcout.start        <= '0';
    done_bit.hash_init <= '0';
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
          done_bit.hash_init <= '1';
        WHEN OTHERS => NULL;
      END CASE;
    END IF;
  END PROCESS;

  -- ---------------------------------------------
  -- ----------------- insert item ---------------
  -- ---------------------------------------------
  -- ---------------------------------------------
  insert_fsm_comb : PROCESS(start_bit, mcin)
  BEGIN

  END PROCESS;
  insert_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

  END PROCESS;
  
  
END ARCHITECTURE syn_dsl_wrapper;
