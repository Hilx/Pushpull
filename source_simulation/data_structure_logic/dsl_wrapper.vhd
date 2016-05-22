LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_wrapper IS
  PORT(
    clk       : IN  STD_LOGIC;
    rst       : IN  STD_LOGIC;
    -- dsl communication
    dsl_in    : IN  dsl_com_in_type;
    dsl_out   : OUT dsl_com_out_type;
    -- allocator communication
    alloc_in  : IN  allocator_com_type;
    alloc_out : OUT allocator_com_type;
    -- memory controller communication
    mcin      : IN  mem_control_type;
    mcout     : OUT mem_control_type
    );
END ENTITY dsl_wrapper;

ARCHITECTURE syn_dsl_wrapper OF dsl_wrapper IS
  SIGNAL dsl_state, dsl_nstate : dsl_overall_control_state_type;
  SIGNAL start_bit, done_bit   : dsl_internal_control_type;

  SIGNAL lookup_result : dsl_lookup_result_type;

  SIGNAL node_access_request_wire  : node_access_comm_type;
  SIGNAL node_access_response_wire : node_access_comm_type;

  TYPE node_access_mem_part_control_type IS (idle, na);
  SIGNAL na_state, na_nstate             : node_access_mem_part_control_type;
  SIGNAL node_access_mem_bit             : STD_LOGIC;
  SIGNAL mcin_naccess                    : mem_control_type;
  SIGNAL mcout_naccess                   : mem_control_type;
  SIGNAL mcin_ild, mcout_ild             : mem_control_type;
  SIGNAL mcin_da, mcout_da               : mem_control_type;
  SIGNAL mcin_init_hash, mcout_init_hash : mem_control_type;
  SIGNAL mc_init                         : mem_control_type;

  SIGNAL alloc_in_da, alloc_in_ild   : allocator_com_type;
  SIGNAL alloc_out_da, alloc_out_ild : allocator_com_type;

  SIGNAL dsl_out_i : dsl_com_out_type;
BEGIN
-- init
  mc_init.start <= '0';


  -- data structure logic overall control
  dsl_fsm_comb : PROCESS(dsl_state, dsl_in, done_bit)
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
        IF done_bit.ild = '1' OR done_bit.delete_all = '1' OR done_bit.init_hash = '1' THEN
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
    start_bit.ild        <= '0';
    start_bit.delete_all <= '0';
    start_bit.init_hash  <= '0';
    dsl_out_i.done       <= '0';
    dsl_out_i.data       <= x"7FFF0000";        -- indicating not looking up
    IF rst = CONST_RESET THEN
      dsl_state <= idle;
    ELSE
      IF dsl_state = start THEN
        CASE dsl_in.cmd IS
          WHEN insert     => start_bit.ild        <= '1';
          WHEN delete     => start_bit.ild        <= '1';
          WHEN lookup     => start_bit.ild        <= '1';
          WHEN delete_all => start_bit.delete_all <= '1';
          WHEN init_hash  => start_bit.init_hash  <= '1';
        END CASE;
      END IF;
      IF dsl_state = done THEN                  -- feedback to outside
        dsl_out_i.done <= '1';                  -- done bit
        IF dsl_in.cmd = lookup THEN
          IF lookup_result.found = '1' THEN
            dsl_out_i.data <= lookup_result.data;
          ELSE
            dsl_out_i.data <= (OTHERS => '1');  -- indicating not found
          END IF;
        END IF;
      -- --------------------------- REMEMBER TO ADD OTHER RESULT OUTPUT
      END IF;
    END IF;
  END PROCESS;

  -- -----------------------------------------------------------
  -- ------------------ memory and allocator access partition --
  -- -----------------------------------------------------------
  na_sel_comb : PROCESS(na_state,
                        node_access_request_wire,
                        node_access_response_wire)
  BEGIN
    na_nstate <= idle;
    CASE na_state IS
      WHEN idle => node_access_mem_bit <= '0';
                   na_nstate <= idle;
                   IF node_access_request_wire.start = '1' THEN
                     na_nstate <= na;
                   END IF;
      WHEN na => node_access_mem_bit <= '1';
                 na_nstate <= na;
                 IF node_access_response_wire.done = '1' THEN
                   na_nstate <= idle;
                 END IF;
    END CASE;
  END PROCESS;

  na_sel_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    na_state <= na_nstate;
    IF rst = CONST_RESET THEN
      na_state <= idle;
    END IF;
  END PROCESS;

  mem_part : PROCESS(dsl_in, node_access_mem_bit, mcin, mcout_ild,
                     mcout_naccess, mcout_da, mcout_init_hash,
                     alloc_out_ild, alloc_out_da, alloc_in, mc_init)
  BEGIN
    -- defaults
    mcout          <= mc_init;
    mcin_ild       <= mc_init;
    mcin_init_hash <= mc_init;
    mcin_da        <= mc_init;
    mcin_naccess   <= mc_init;
    IF dsl_in.cmd = insert OR dsl_in.cmd = delete OR dsl_in.cmd = lookup THEN
      mcout    <= mcout_ild;
      mcin_ild <= mcin;
      IF node_access_mem_bit = '1' THEN
        mcout        <= mcout_naccess;
        mcin_naccess <= mcin;
      END IF;
    ELSIF dsl_in.cmd = delete_all THEN
      mcout   <= mcout_da;
      mcin_da <= mcin;
    ELSIF dsl_in.cmd = init_hash THEN
      mcout          <= mcout_init_hash;
      mcin_init_hash <= mcin;
    END IF;

    alloc_in_ild <= alloc_in;
    alloc_in_da  <= alloc_in;
    alloc_out    <= alloc_out_ild;
    IF dsl_in.cmd = delete_all THEN
      alloc_out <= alloc_out_da;
    END IF;
    

    

  END PROCESS;

  -- ---------------------------------------------
  -- ------------------ PORT MAPS ----------------
  -- ---------------------------------------------
  inithash0 : ENTITY dsl_init_hash
    PORT MAP(
      clk => clk,
      rst => rst,

      start_b => start_bit.init_hash,
      done_b  => done_bit.init_hash,
      mcin    => mcin_init_hash,
      mcout   => mcout_init_hash
      );

  de_all0 : ENTITY dsl_delete_all
    PORT MAP(
      clk       => clk,
      rst       => rst,
      start     => start_bit.delete_all,
      done      => done_bit.delete_all,
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
      key           => dsl_in.key,
      data          => dsl_in.data,
      lookup_result => lookup_result,
      node_request  => node_access_request_wire,
      node_response => node_access_response_wire,
      alloc_in      => alloc_in_ild,
      alloc_out     => alloc_out_ild,
      mcin          => mcin_ild,
      mcout         => mcout_ild
      );

  na0 : ENTITY dsl_node_access
    PORT MAP(
      clk      => clk,
      rst      => rst,
      request  => node_access_request_wire,
      response => node_access_response_wire,
      mcin     => mcin_naccess,
      mcout    => mcout_naccess
      );

  dsl_out <= dsl_out_i;

END ARCHITECTURE syn_dsl_wrapper;
