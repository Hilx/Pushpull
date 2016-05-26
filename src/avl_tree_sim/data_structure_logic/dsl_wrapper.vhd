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
    sys_init  : IN  STD_LOGIC;
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
  SIGNAL lookup_result         : dsl_lookup_result_type;
  SIGNAL dsl_out_i             : dsl_com_out_type;

  -- node access arbitration
  SIGNAL node_request_wire, node_response_wire             : node_access_comm_type;
  SIGNAL node_request_insert, node_response_insert         : node_access_comm_type;
  SIGNAL node_request_delete, node_response_delete         : node_access_comm_type;
  SIGNAL node_request_delete_all, node_response_delete_all : node_access_comm_type;
  SIGNAL node_request_lookup, node_response_lookup         : node_access_comm_type;
  SIGNAL node_acc_init                                     : node_access_comm_type;

  -- allocator access arbitration
  SIGNAL alloc_request_insert, alloc_result_insert         : allocator_com_type;
  SIGNAL alloc_request_delete, alloc_result_delete         : allocator_com_type;
  SIGNAL alloc_request_delete_all, alloc_result_delete_all : allocator_com_type;
  SIGNAL alloc_acc_init                                    : allocator_com_type;

  -- rootPtr control
  SIGNAL rootPtr, rootPtr_from_insert, rootPtr_from_delete : slv(31 DOWNTO 0);
BEGIN
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
        IF done_bit.insert = '1' OR done_bit.delete_all = '1'
          OR done_bit.lookup = '1'OR done_bit.delete = '1' THEN
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

    dsl_out_i.done <= '0';
    -- dsl_out_i.data       <= x"7FFF0000";        -- indicating not looking up
    IF rst = CONST_RESET THEN
      dsl_state      <= idle;
      dsl_out_i.data <= x"00000000";
    ELSE
      IF dsl_state = idle THEN
        IF sys_init = '1' THEN          -- when memory allocator is initialised
          rootPtr <= nullPtr;           -- initialised rootPtr reg to nullPtr
        END IF;
      END IF;
      IF dsl_state = start THEN
        CASE dsl_in.cmd IS
          WHEN insert     => start_bit.insert     <= '1';
          WHEN delete     => start_bit.delete     <= '1';
          WHEN lookup     => start_bit.lookup     <= '1';
          WHEN delete_all => start_bit.delete_all <= '1';
          WHEN OTHERS     => NULL;
        END CASE;
      END IF;
      IF dsl_state = done THEN          -- feedback to outside
        dsl_out_i.done <= '1';          -- done bit
        IF dsl_in.cmd = lookup THEN
          IF lookup_result.found = '1' THEN
            dsl_out_i.data <= lookup_result.data;
          ELSE
            dsl_out_i.data <= (OTHERS => '1');  -- indicating not found
          END IF;
        ELSIF dsl_in.cmd = insert THEN
          rootPtr <= rootPtr_from_insert;
        ELSIF dsl_in.cmd = delete THEN
          rootPtr <= rootPtr_from_delete;
        ELSIF dsl_in.cmd = delete_all THEN  -- after deleting the entire tree
          rootPtr <= nullPtr;           -- make rootPtr reg value nullPtr again
        END IF;
      -- --------------------------- REMEMBER TO ADD OTHER RESULT OUTPUT
      -- (forgot what i meant for this...)
      END IF;
    END IF;
  END PROCESS;

  -- -----------------------------------------------------------
  -- ----------- node and allocator access partition -----------
  -- -----------------------------------------------------------
  node_acc_init.start         <= '0';
  node_acc_init.done          <= '0';
  node_acc_init.cmd           <= rnode;
  node_acc_init.node.key      <= (OTHERS => '0');
  node_acc_init.node.data     <= (OTHERS => '0');
  node_acc_init.node.leftPtr  <= (OTHERS => '0');
  node_acc_init.node.rightPtr <= (OTHERS => '0');
  node_acc_init.node.height   <= 0;
  node_acc_init.ptr           <= (OTHERS => '0');
  node_acc_init.node.ptr      <= (OTHERS => '0');
  alloc_acc_init.start        <= '0';
  alloc_acc_init.cmd          <= malloc;
  alloc_acc_init.ptr          <= (OTHERS => '0');
  alloc_acc_init.done         <= '0';
  parti0 : PROCESS(dsl_in,
                   node_response_wire, alloc_in,
                   node_request_insert, alloc_request_insert,
                   node_request_delete, alloc_request_delete,
                   node_request_delete_all, alloc_request_delete_all,
                   node_request_lookup,
                   node_acc_init, alloc_acc_init)
  BEGIN
    node_request_wire        <= node_request_lookup;
    node_response_insert     <= node_acc_init;
    node_response_lookup     <= node_acc_init;
    node_response_delete     <= node_acc_init;
    node_response_delete_all <= node_acc_init;
    alloc_out                <= alloc_request_insert;
    alloc_result_insert      <= alloc_acc_init;
    alloc_result_delete      <= alloc_acc_init;
    alloc_result_delete_all  <= alloc_acc_init;
    IF dsl_in.cmd = insert THEN
      node_request_wire    <= node_request_insert;
      node_response_insert <= node_response_wire;
      alloc_out            <= alloc_request_insert;
      alloc_result_insert  <= alloc_in;
    ELSIF dsl_in.cmd = lookup THEN
      node_request_wire    <= node_request_lookup;
      node_response_lookup <= node_response_wire;
    ELSIF dsl_in.cmd = delete THEN
      node_request_wire    <= node_request_delete;
      node_response_delete <= node_response_wire;
      alloc_out            <= alloc_request_delete;
      alloc_result_delete  <= alloc_in;
    ELSIF dsl_in.cmd = delete_all THEN
      node_request_wire        <= node_request_delete_all;
      node_response_delete_all <= node_response_wire;
      alloc_result_delete_all  <= alloc_in;
      alloc_out                <= alloc_request_delete_all;
    END IF;

  END PROCESS;

  -- ---------------------------------------------
  -- ------------------ PORT MAPS ----------------
  -- ---------------------------------------------
  na0 : ENTITY dsl_node_access
    PORT MAP(
      clk      => clk,
      rst      => rst,
      request  => node_request_wire,
      response => node_response_wire,
      mcin     => mcin,
      mcout    => mcout
      );
  ins0 : ENTITY dsl_insert
    PORT MAP(
      clk                => clk,
      rst                => rst,
      rootPtr_IN         => rootPtr,
      rootPtr_OUT        => rootPtr_from_insert,
      start              => start_bit.insert,
      done               => done_bit.insert,
      key                => dsl_in.key,
      data               => dsl_in.data,
      node_request_port  => node_request_insert,
      node_response_port => node_response_insert,
      alloc_in           => alloc_result_insert,
      alloc_out          => alloc_request_insert
      );
  lookup0 : ENTITY dsl_lookup
    PORT MAP(
      clk                => clk,
      rst                => rst,
      rootPtr_IN         => rootPtr,
      start              => start_bit.lookup,
      done               => done_bit.lookup,
      key                => dsl_in.key,
      lookup_result      => lookup_result,
      node_request_port  => node_request_lookup,
      node_response_port => node_response_lookup
      );
  del0 : ENTITY dsl_delete
    PORT MAP(
      clk                => clk,
      rst                => rst,
      rootPtr_IN         => rootPtr,
      rootPtr_OUT        => rootPtr_from_delete,
      start              => start_bit.delete,
      done               => done_bit.delete,
      key                => dsl_in.key,
      node_request_port  => node_request_delete,
      node_response_port => node_response_delete,
      alloc_in           => alloc_result_delete,
      alloc_out          => alloc_request_delete
      );
  da0 : ENTITY dsl_delete_all
    PORT MAP(
      clk           => clk,
      rst           => rst,
      start         => start_bit.delete_all,
      done          => done_bit.delete_all,
      rootPtr_IN    => rootPtr,
      alloc_in      => alloc_result_delete_all,
      alloc_out     => alloc_request_delete_all,
      node_request  => node_request_delete_all,
      node_response => node_response_delete_all
      );  

  dsl_out <= dsl_out_i;

END ARCHITECTURE syn_dsl_wrapper;
