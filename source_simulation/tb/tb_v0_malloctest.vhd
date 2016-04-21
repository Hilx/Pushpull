LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.config_pack.ALL;
USE work.dsa_top_pack.ALL;
USE work.tb_pack_v0.ALL;                -- malloc-only testing tb package

ENTITY tb_v0 IS
END ENTITY tb_v0;

ARCHITECTURE behav_tb_v0 OF tb_v0 IS
  ALIAS slv IS STD_LOGIC_VECTOR;
  -- system signals
  SIGNAL clk           : STD_LOGIC;
  SIGNAL rst           : STD_LOGIC;
  -- port mapping dsa
  SIGNAL myPtr         : slv(31 DOWNTO 0);  -- pointer allocated returned
  SIGNAL mmu_init_bit  : STD_LOGIC;     -- allocator initialisation start bit
  SIGNAL mmu_init_done : STD_LOGIC;     -- allocator initialisation done bit
  SIGNAL dsa_req       : dsa_request_type;  -- test input send to dsa
  SIGNAL dsa_response  : dsl_com_out_type;  -- feedback from dsa block
  SIGNAL m_request     : mem_control_type;  -- memory control from dsa
  SIGNAL m_response    : mem_control_type;  -- memory control to dsa
  -- memory signals
  -- ?

  -- tb fsm signals
  SIGNAL tb_state, tb_nstate    : tb_fsm_v0_type;
  SIGNAL start_bit, flag_finish : STD_LOGIC;
  -- for extracting inputs from package
  SIGNAL test_index             : INTEGER;
  
BEGIN
  -- -------------------------------------
  -- ----- Connections and Port Maps -----
  -- -------------------------------------  
  dsa0 : ENTITY dsa_top_wrapper
    PORT MAP(
      PTR_OUT       => myPtr,
      clk           => clk,
      rst           => rst,
      mmu_init_bit  => mmu_init_bit,
      mmu_init_done => mmu_init_done,
      -- dsl communication
      request       => dsa_req,
      response      => dsa_response,
      -- memory controller communciation
      tmc_in        => m_request,
      tmc_out       => m_response
      );

  -- -------------------------------------
  -- ---------- Clock Generation ---------
  -- -------------------------------------  
  p1_clkgen : PROCESS
  BEGIN
    clk <= '0';
    WAIT FOR 50 ns;
    clk <= '1';
    WAIT FOR 50 ns;
  END PROCESS p1_clkgen;

  -- -------------------------------------
  -- TB FSM: init and send commands ------
  -- -------------------------------------
  tb_fsm0_comb : PROCESS(tb_state, start_bit,
                         mmu_init_done, dsa_response,
                         test_index
                         )
  BEGIN
    tb_nstate <= idle;
    CASE tb_state IS
      WHEN idle =>
        tb_nstate <= idle;
        IF start_bit = '1' THEN
          tb_nstate <= init;
        END IF;
      WHEN init =>
        tb_nstate <= initing;
      WHEN initing =>
        tb_nstate <= initing;
        IF mmu_init_done = '1' THEN
          tb_nstate <= ready;
        END IF;
      WHEN ready =>
        tb_nstate <= command;
      WHEN command =>
        tb_nstate <= busy;
      WHEN busy =>
        tb_nstate <= busy;
        IF dsa_response = '1' THEN
          tb_nstate <= check;
        END IF;
      WHEN check =>
        tb_nstate <= command;
        IF myTest(test_index).last = '1' THEN
          tb_nstate <= finish;
        END IF;
      WHEN finish =>
        ASSERT false REPORT "TEST FINISHED" SEVERITY failure;  -- stop tb
    END CASE;
  END PROCESS;

  tb_fsm0_reg : PROCESS
  BEGIN
    WAIT clk'event AND clk = '1';

    tb_state      <= tb_nstate;
    mmu_init_bit  <= '0';
    dsa_req.start <= '0';

    IF rst = CONST_RESET THEN
      tb_state <= idle;
    ELSE
      CASE tb_state IS
        WHEN init =>
          mmu_init_bit <= '1';
          test_index   <= 0;
        WHEN command =>
          dsa_req.request_in <= myTest(test_index).req;
          dsa_req.start      <= '1';
          -- update text extracting info
          test_index         <= test_index + 1;
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset stuff    
  END PROCESS;



END ARCHITECTURE behav_tb_v0;
