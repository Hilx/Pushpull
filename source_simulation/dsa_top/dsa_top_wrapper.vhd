LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.dsa_top_pack.ALL;
USE work.malloc_pack.ALL;               -- memory management package
USE work.dsl_pack.ALL;                  -- data structure logic package

ENTITY dsa_top_wrapper IS
  PORT(
    PTR_OUT       : OUT STD_LOGIC;         -- for testing malloc.
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    mmu_init_bit  : IN  STD_LOGIC;         -- allocator initialisation command
    mmu_init_done : OUT STD_LOGIC;
    -- dsl communication
    request       : IN  slv(31 DOWNTO 0);  -- untranslated request input
    response      : OUT dsl_com_out_type;
    -- memory controller communciation
    tmc_in        : IN  dsa_top_mem_control_type;
    tmc_out       : OUT dsa_top_mem_control_type
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
  
BEGIN
  -- -------------------------------------
  -- ----- Connections and Port Maps -----
  -- -------------------------------------  
  response      <= dsl_response;        -- returns corresp. data and done bit
  mmu_init_done <= mmu_init_done_i;
  alloc0 : ENTITY malloc_wrapper
    PORT MAP(
      clk           => clk,
      rst           => rst,
      mmu_init_bit  => mmu_init_bit,
      mmu_init_done => mmu_init_done_i,
      -- Interval/DS communication
      argu          => alloc_cmd,
      retu          => alloc_resp,
      -- External/Memory communication
      memcon_in     => alloc_mc_resp,
      memcon_out    => alloc_mc_cmd
      );

  dsl0 : ENTITY dsl_wrapper
    PORT MAP(
      clk       => clk,
      rst       => rst,
      -- dsl communication
      dsl_in    => dsl_request,
      dsl_out   => dsl_response,
      -- allocator communication
      alloc_in  => alloc_resp,
      alloc_out => alloc_cmd,
      -- memory controller communication
      mcin      => dsl_mc_resp,
      mcout     => dsl_mc_cmd
      );

  -- -------------------------------------
  -- ----- MEMORY ACCESS ARBITRATOR ------
  -- -------------------------------------
  -- memory access arbitrator fsm stuff
  -- TYPE maa_state_type(maa_state_ds, maa_state_alloc);
  maa_fsm_comb : PROCESS(maa_state,
                         mmu_init_bit, mmu_init_done,
                         alloc_cmd, alloc_resp)
  BEGIN
    maa_nstate <= maa_state_ds;
    CASE maa_state IS
      WHEN maa_state_ds =>
        maa_nstate <= maa_state_ds;     -- by default, keep same state
        IF mmu_init_bit = '1' OR alloc_cmd.start = '1' THEN
          maa_nstate <= maa_state_alloc;
        END IF;
      WHEN maa_state_alloc =>
        maa_nstate <= maa_state_alloc;
        IF mmu_init_done = '1' OR alloc_resp.done = '1' THEN
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
    tmc_out      <= dsl_mc_cmd;
    IF maa_state <= maa_state_alloc THEN
      tmc_out <= alloc_mc_cmd;
    END IF;
  END PROCESS maa_connect;

  -- -------------------------------------
  -- ---- Client Request Translator ------
  -- ------------- STAGING ---------------
  -- -------------------------------------
  -- - CURRENTLY ONLY FOR TESTING MALLOC -

  dsl_request.cmd <= request(1 DOWNTO 0);

  tra_cmd_comb : PROCESS(request)
  BEGIN
    dsl_request.cmd <= insert;
    IF request(1 DOWNTO 0) = b"01" THEN
      dsl_request.cmd <= delete;
    END IF;
  END PROCESS;

  tra_fsm_comb : PROCESS(tra_state, request, del_response)
  BEGIN
    tra_nstate <= tra_state_idle;
    CASE tra_state IS
      WHEN tra_state_idle =>
        tra_nstate <= tra_state_idle;
        IF request.start = '1' THEN
          tra_nstate <= tra_state_start;
        END IF;
      WHEN tra_state_start =>
        tra_nstate <= tra_state_wait;
      WHEN tra_state_wait =>
        tra_nstate <= tra_state_wait;
        IF dsl_response.done = '1' THEN
          tra_nstate <= tra_state_done;
        END IF;
      WHEN tra_state_done =>
        tra_nstate <= tra_state_idle;
    END CASE;
  END PROCESS;

  tra_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    tra_state         <= tra_nstate;
    dsl_request.start <= '0';
    IF rst = CONST_RESET THEN
      tra_state <= tra_state_idle;
    ELSE
      IF tra_state THEN
        tra_state_start => dsl_request.start <= '1';
      END IF;
    END IF;
  END PROCESS;

  -- FOR TESTING
  PTR_OUT <= alloc_resp.ptr;
  
END ARCHITECTURE syn_dsa_top_wrapper;

