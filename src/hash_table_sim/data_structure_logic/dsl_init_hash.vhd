LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_init_hash IS
  PORT(
    clk                     : IN  STD_LOGIC;
    rst                     : IN  STD_LOGIC;
    start_b                 : IN  STD_LOGIC;
    done_b                  : OUT STD_LOGIC;
    alloc_in                : IN  allocator_com_type;
    alloc_out               : OUT allocator_com_type;
    mcin                    : IN  mem_control_type;
    mcout                   : OUT mem_control_type;
    tablePtr                : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    flag_initiating_entries : OUT STD_LOGIC
    );
END ENTITY dsl_init_hash;

ARCHITECTURE syn_dsl_init_hash OF dsl_init_hash IS
  ALIAS uns IS UNSIGNED;
  SIGNAL init_state, init_nstate : hash_init_state_type;
  SIGNAL entry_count, tablePtr_i : slv(31 DOWNTO 0);
  SIGNAL mem_addr                : slv(31 DOWNTO 0);

BEGIN
  -- ---------------------------------------------
  -- ---------- hash table initialisation --------
  -- -------- write nullPtr as hash entries ------
  -- ---------------------------------------------
  init_fsm_comb : PROCESS(start_b, init_state, mcin,
                          entry_count, alloc_in)
  BEGIN
    init_nstate <= idle;
    CASE init_state IS
      WHEN idle =>
        init_nstate <= idle;
        IF start_b = '1' THEN
          init_nstate <= malloc_start;
        END IF;
      WHEN malloc_start => init_nstate <= malloc_wait;
      WHEN malloc_wait  => init_nstate <= malloc_wait;
                           IF alloc_in.done = '1' THEN
                             init_nstate <= malloc_done;
                           END IF;
      WHEN malloc_done => init_nstate <= wstart;
      WHEN wstart =>
        init_nstate <= wwait;
      WHEN wwait =>
        init_nstate <= wwait;
        IF mcin.done = '1' THEN
          init_nstate <= compute;
        END IF;
      WHEN compute =>
        init_nstate <= wstart;
        IF entry_count = slv(to_unsigned(TOTAL_HASH_ENTRY, 32)) THEN
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
    init_state      <= init_nstate;
    mcout.start     <= '0';
    done_b          <= '0';
    alloc_out.start <= '0';
    IF rst = CONST_RESET THEN
      init_state <= idle;
    ELSE
      CASE init_state IS
        WHEN idle =>
          entry_count <= (OTHERS => '0');

          mcout.wdata             <= nullPtr;
          mcout.cmd               <= mwrite;
          flag_initiating_entries <= '0';
          alloc_out.istype        <= hash_entries;
          IF start_b = '1' THEN
            flag_initiating_entries <= '1';
          END IF;
        WHEN malloc_start => alloc_out.start <= '1';
                             alloc_out.istype <= hash_entries;
        WHEN malloc_done => tablePtr_i <= alloc_in.ptr;
                            mem_addr <= alloc_in.ptr;
        WHEN wstart =>
          mcout.start <= '1';
          entry_count <= slv(uns(entry_count) + 1);
        WHEN compute =>
          mem_addr <= slv(uns(mem_addr) + ADDR_WORD_OFF_DEC);
        WHEN done =>
          done_b <= '1';
        WHEN OTHERS => NULL;
      END CASE;
    END IF;
  END PROCESS;

  tablePtr <= tablePtr_i;

END ARCHITECTURE;
