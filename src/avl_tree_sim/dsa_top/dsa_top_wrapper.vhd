LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.config_pack.ALL;
USE work.dsa_top_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

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

  SIGNAL total_entry_offset : slv(31 DOWNTO 0);

  SIGNAL mmu_init_start_i : STD_LOGIC;

  SIGNAL dsl_response_i : dsl_com_out_type;

  -- multiple roots
  SIGNAL roots_we                    : STD_LOGIC;
  SIGNAL roots_addr                  : slv(ROOTS_RAM_ADDR_BITS-1 DOWNTO 0);
  SIGNAL roots_data_in, root_updated : slv(31 DOWNTO 0);
  SIGNAL roots_data_out, root_stored : slv(31 DOWNTO 0);
  SIGNAL root_state, root_nstate     : roots_update_state_type;
  SIGNAL roots_addr_i, root_sel      : INTEGER;
  
  
  
BEGIN
  -- -------------------------------------
  -- ----- Connections and Port Maps -----
  -- -------------------------------------
  rootsmem : ENTITY roots_ram
    PORT MAP(
      clk      => clk,
      we       => roots_we,
      address  => roots_addr,
      data_in  => roots_data_in,
      data_out => roots_data_out
      );

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
      sys_init  => mmu_init_start_i,
      -- root
      root_in   => root_stored,
      root_out  => root_updated,
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
      WHEN MALLOC_INIT => dsl_request.start <= '0';
                          mmu_init_start_i <= request.start;
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
      WHEN LOOKUP_L => dsl_request.cmd <= lookup_larger_cmd;
                       dsl_request.start <= request.start;
                       mmu_init_start_i  <= '0';
      WHEN OTHERS => dsl_request.cmd <= lookup;
                     dsl_request.start <= request.start;
                     mmu_init_start_i  <= '0';
    END CASE;
  END PROCESS;


  -- -------------------------------------
  -- ---------- ROOTS --------------------
  -- -------------------------------------
  rootfsm_comb : PROCESS(root_state, request, dsl_response_i, mmu_init_start_i,roots_addr_i)
  BEGIN
    root_nstate <= idle;
    CASE root_state IS
      WHEN idle => root_nstate <= idle;
                   IF mmu_init_start_i = '1' THEN
                     root_nstate <= init_start;
                   ELSIF request.start = '1' THEN
                     root_nstate <= read_new;
                   END IF;
      WHEN read_new => root_nstate <= busy;
      WHEN busy     => root_nstate <= busy;
                       IF dsl_response_i.done = '1' THEN
                         root_nstate <= new_in;
                       END IF;
      WHEN new_in     => root_nstate      <= write_out;
      WHEN write_out  => root_nstate      <= idle;
      -- initialisations
      WHEN init_start => root_nstate <= init_w0;
      WHEN init_w0    => root_nstate <= init_w1;
      WHEN init_w1    => root_nstate <= init_w2;
      WHEN init_w2    => root_nstate <= init_au;
      WHEN init_au    => root_nstate <= init_w0;
                         IF roots_addr_i = MAX_ROOTS_RAM_ADDR THEN
                           root_nstate <= idle;
                         END IF;
      WHEN OTHERS => root_nstate <= idle;
    END CASE;
  END PROCESS;

  rootfsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    root_state <= root_nstate;
    roots_we   <= '0';
    IF rst = CONST_RESET THEN
      root_state <= idle;
    ELSE

      -- -------------------------------
      -- BETTER WITH CASE STATEMENTS!!!!!!!!!!!!!
      
      IF root_state = idle THEN
        roots_addr_i <= root_sel;
      END IF;
      IF root_state = read_new THEN
        root_stored <= roots_data_out;
      END IF;
      IF root_state = new_in THEN
        roots_data_in <= root_updated;
      END IF;
      IF root_state = write_out THEN
        roots_we <= '1';
      END IF;

      -- roots initialisation (to nullPtrs)
      IF root_state = init_start THEN
        roots_addr_i  <= 0;
        roots_data_in <= nullPtr;
      END IF;
      IF root_state = init_w0 THEN
        roots_we <= '1';
      END IF;
      IF root_state = init_au AND roots_addr_i /= MAX_ROOTS_RAM_ADDR THEN
        roots_addr_i <= roots_addr_i +1;
      END IF;
      
    END IF;  -- if reset

  END PROCESS;
  roots_addr <= slv(to_unsigned(roots_addr_i, ROOTS_RAM_ADDR_BITS));
  root_sel   <= request.root_sel;
  -- --------------------------------------

  dsl_request.key  <= request.key;
  dsl_request.data <= request.data;

  -- FOR TESTING
  PTR_OUT <= alloc_resp.ptr;

END ARCHITECTURE syn_dsa_top_wrapper;

