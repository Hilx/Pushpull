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
  SIGNAL dsl_state, dsl_nstate : dsl_overall_control_state_type;
  SIGNAL start_bit, done_bit   : dsl_internal_control_type;

  SIGNAL mcin_init_hash, mcout_init_hash : mem_control_type;

  SIGNAL lookup_result : dsl_lookup_result_type;

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
  -- ------------------ PORT MAPS ----------------
  -- ---------------------------------------------
  init0 : ENTITY dsl_init_hash
    PORT MAP(
      clk         => clk,
      rst         => rst,
      total_entry => total_entry,
      start_b     => start_bit.init_hash,
      done_b      => done_bit.init_hash,
      mcin        => mcin_init_hash,
      mcout       => mcout_init_hash
      );

  de_all0 : ENTITY dsl_delete_all
    PORT MAP(
      clk       => clk,
      rst       => rst,
      start     => start_bit.da,
      done      => done_bit.da,
      alloc_in  => alloc_in_da,
      alloc_out => alloc_out_da,
      mcin      => mcin_da,
      mcout     => mcout_da
      );

  ild0 : ENTITY dsl_ild
    PORT MAP(
      clk           => clk,
      rst           => rst,
      start         => start_bit.ild,
      cmd           => dsl_in.cmd,
      done          => done_bit.ild,
      lookup_result => lookup_result,
      alloc_in      => alloc_in_ild,
      alloc_out     => alloc_out_ild,
      mcin          => mcin_ild,
      mcout         => cout_ild
      );

END ARCHITECTURE syn_dsl_wrapper;
