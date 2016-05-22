LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.config_pack.ALL;
USE work.dsa_top_pack.ALL;
USE work.malloc_pack.ALL;               -- memory management package
USE work.dsl_pack.ALL;                  -- data structure logic package

ENTITY dsa_top_wrapper IS
  PORT(
    PTR_OUT      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  -- for testing malloc
    clk          : IN  STD_LOGIC;
    rst          : IN  STD_LOGIC;
    -- dsl communication
    request      : IN  dsa_request_type;  -- untranslated request input
    dsl_data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    DSA_DONE_BIT : OUT STD_LOGIC;
    -- memory controller communciation
    tmc_in       : IN  mem_control_type;
    tmc_out      : OUT mem_control_type
    );
END ENTITY dsa_top_wrapper;

ARCHITECTURE syn_dsa_top_wrapper OF dsa_top_wrapper IS
  -- wiring signals
  SIGNAL alloc_cmd, alloc_resp : allocator_com_type;

  -- memory access arbitrator signals
  SIGNAL alloc_mc_cmd, alloc_mc_resp : mem_control_type;
  SIGNAL dsl_mc_cmd, dsl_mc_resp     : mem_control_type;
  SIGNAL maa_state, maa_nstate       : maa_state_type;
  SIGNAL mmu_init_done_i             : STD_LOGIC;

  -- client command translator signals
  SIGNAL dsl_request  : dsl_com_in_type;
  SIGNAL dsl_response : dsl_com_out_type;

  -- FOR TESTING MALLOC NOW, translator signals
  SIGNAL tra_state, tra_nstate : tra_state_type;

  SIGNAL total_entry_offset : STD_LOGIC_VECTOR(31 DOWNTO 0);

  SIGNAL mmu_init_start_i : STD_LOGIC;

  SIGNAL dsl_response_i : dsl_com_out_type;
  
BEGIN
  -- -------------------------------------
  -- ---- total entry info ---------------
  -- -------------------------------------
  total_entry_offset <= slv(TO_UNSIGNED(TOTAL_HASH_ENTRY, 32) SLL ADDR_WORD_OFF_BIN);

  -- -------------------------------------
  -- ----- Connections and Port Maps -----
  -- -------------------------------------  
  --response      <= dsl_response;        -- returns corresp. data and done bit
  --mmu_init_done <= mmu_init_done_i;
  alloc0 : ENTITY malloc_wrapper
    PORT MAP(
      clk                => clk,
      rst                => rst,
      total_entry_offset => total_entry_offset,
      mmu_init_bit       => mmu_init_start_i,  -- mmu_init_bit,
      mmu_init_done      => mmu_init_done_i,
      -- Interval/DS communication
      argu               => alloc_cmd,
      retu               => alloc_resp,
      -- External/Memory communication
      memcon_in          => alloc_mc_resp,
      memcon_out         => alloc_mc_cmd
      );

  dsl0 : ENTITY dsl_wrapper
    PORT MAP(
      clk       => clk,
      rst       => rst,
      -- dsl communication
      dsl_in    => dsl_request,
      dsl_out   => dsl_response_i,
      -- allocator communication
      alloc_in  => alloc_resp,
      alloc_out => alloc_cmd,
      -- memory controller communication
      mcin      => dsl_mc_resp,
      mcout     => dsl_mc_cmd
      );
  dsl_data_out <= dsl_response_i.data;
  DSA_DONE_BIT <= dsl_response_i.done OR mmu_init_done_i;
  -- -------------------------------------
  -- ----- MEMORY ACCESS ARBITRATOR ------
  -- -------------------------------------
  -- memory access arbitrator fsm stuff
  -- TYPE maa_state_type(maa_state_ds, maa_state_alloc);
  maa_fsm_comb : PROCESS(maa_state,
                         mmu_init_start_i, mmu_init_done_i,
                         alloc_cmd, alloc_resp)
  BEGIN
    maa_nstate <= maa_state_ds;
    CASE maa_state IS
      WHEN maa_state_ds =>
        maa_nstate <= maa_state_ds;     -- by default, keep same state
        IF mmu_init_start_i = '1' OR alloc_cmd.start = '1' THEN
          maa_nstate <= maa_state_alloc;
        END IF;
      WHEN maa_state_alloc =>
        maa_nstate <= maa_state_alloc;
        IF mmu_init_done_i = '1' OR alloc_resp.done = '1' THEN
          maa_nstate <= maa_state_ds;
        END IF;
    END CASE;
  END PROCESS maa_fsm_comb;

  maa_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    maa_state <= maa_nstate;
    IF rst = CONST_RESET THEN
      maa_state <= maa_state_ds;
    END IF;
  END PROCESS maa_fsm_reg;

  alloc_mc_resp <= tmc_in;
  dsl_mc_resp   <= tmc_in;
  maa_connect : PROCESS(maa_state, dsl_mc_cmd, alloc_mc_cmd)
  BEGIN
    tmc_out <= dsl_mc_cmd;
    IF maa_state = maa_state_alloc THEN
      tmc_out <= alloc_mc_cmd;
    END IF;
  END PROCESS maa_connect;

  -- -------------------------------------
  -- ---- Client Request Translator ------
  -- ------------- STAGING ---------------
  -- -------------------------------------

  tra_cmd_comb : PROCESS(request)
  BEGIN
    dsl_request.cmd <= lookup;

    dsl_request.start <= '0';
    mmu_init_start_i  <= '0';

    CASE request.cmd IS
      WHEN MALLOC_INIT =>
        --mmu_init_start_i  <= request.start;
        dsl_request.start <= '0';
        mmu_init_start_i  <= request.start;
      WHEN HASH_INIT => dsl_request.cmd <= init_hash;
                        dsl_request.start <= request.start;
                        mmu_init_start_i  <= '0';
      WHEN INS_ITEM => dsl_request.cmd <= insert;
                       dsl_request.start <= request.start;
                       mmu_init_start_i  <= '0';
      WHEN DEL_ITEM => dsl_request.cmd <= delete;
                       dsl_request.start <= request.start;
                       mmu_init_start_i  <= '0';
      WHEN SER_ITEM => dsl_request.cmd <= lookup;
                       dsl_request.start <= request.start;
                       mmu_init_start_i  <= '0';
      WHEN ALL_DELETE => dsl_request.cmd <= delete_all;
                         dsl_request.start <= request.start;
                         mmu_init_start_i  <= '0';
      WHEN OTHERS => dsl_request.cmd <= lookup;
                     dsl_request.start <= request.start;
                     mmu_init_start_i  <= '0';
    END CASE;
  END PROCESS;
  dsl_request.key  <= request.key;
  dsl_request.data <= request.data;

  -- FOR TESTING
  PTR_OUT <= alloc_resp.ptr;
  
END ARCHITECTURE syn_dsa_top_wrapper;

