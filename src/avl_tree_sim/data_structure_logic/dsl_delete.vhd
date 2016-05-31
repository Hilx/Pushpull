LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;
USE work.dsl_pack_func.ALL;

ENTITY dsl_delete IS
  PORT(
    clk                : IN  STD_LOGIC;
    rst                : IN  STD_LOGIC;
    -- root
    rootPtr_IN         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    rootPtr_OUT        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- control
    start              : IN  STD_LOGIC;
    done               : OUT STD_LOGIC;
    -- item
    key                : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- node access
    node_request_port  : OUT node_access_comm_type;
    node_response_port : IN  node_access_comm_type;
    -- allocator
    alloc_in           : IN  allocator_com_type;
    alloc_out          : OUT allocator_com_type
    );
END ENTITY dsl_delete;

ARCHITECTURE syn_dsl_delete OF dsl_delete IS
  ALIAS uns IS UNSIGNED;
  SIGNAL freePtr, returnPtr, nowPtr              : slv(31 DOWNTO 0);
  SIGNAL state, nstate                           : delete_state_type;
  SIGNAL bal_state, bal_nstate                   : delete_bal_state_type;
  SIGNAL node_request, node_request_bal          : node_access_comm_type;
  SIGNAL node_response, node_response_bal        : node_access_comm_type;
  SIGNAL flag_succ, flag_balancing               : STD_LOGIC;
  SIGNAL balancing_start_bit, balancing_done_bit : STD_LOGIC;
  SIGNAL nodeIn, node2update                     : tree_node_type;
  SIGNAL saddr0, saddr1, saddr2update            : INTEGER;
  SIGNAL mystack                                 : stack_type;
BEGIN
  delete_comb : PROCESS(state, start, rootPtr_IN, key,
                        node_response, alloc_in, nodeIn,
                        balancing_done_bit, flag_succ, saddr0)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF start = '1' THEN
                     nstate <= checkroot,
                   END IF;
      WHEN checkroot => nstate <= rnode_start;
                        IF rootPtr_IN = nullPtr THEN
                          nstate <= isdone;
                        END IF;
      -- ----------------------------
      -- ------- READ NODE ----------
      -- ----------------------------
      WHEN rnode_start => nstate <= rnode_wait;
      WHEN rnode_wait  => nstate <= rnode_wait;
                          IF node_response.done = '1 THEN
                            nstate <= rnode_done;
                          END IF;
      WHEN rnode_done => nstate <= comparekey;
                         IF flag_succ = '1' THEN
                           nstate <= succ_ser_compare;
                         END IF;
      -- ----------------------------
      -- ---- SEARCH: COMPARE KEY ---
      -- ----------------------------
      WHEN comparekey =>
        nstate <= write_stack;
        IF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.leftPtr = nullPtr THEN
            nstate <= isdone;
          END IF;
        ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.rightPtr = nullPtr THEN
            nstate <= isdone;
          END IF;
        ELSIF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
          nstate <= keyfound;
        END IF;
      -- ----------------------------
      -- ---------- STACK  ----------
      -- ----------------------------
      WHEN write_stack => nstate <= rnode_start;
      -- ----------------------------
      -- ---- FOUND THE KEY! --------
      -- ----------------------------
      WHEN keyfound =>
        nstate <= read_onechild_wait;   -- if only one child exists
        IF nodeIn.leftPtr = nullPtr AND nodeIn.rightPtr = nullPtr THEN
          nstate <= alloc_start;        -- if no child
        ELSIF nodeIn.leftPtr /= nullPtr AND nodeIn.rightPtr /= nullPtr THEN
          nstate <= write_stack;
        END IF;
      -- ----------------------------
      -- -- FIND INORDER SUCCESSOR --
      -- ----------------------------
      WHEN succ_ser_compare => nstate <= write_stack;
                               IF nodeIn.rightPtr = nullPtr THEN
                                 nstate <= update_stack;
                               END IF;
      WHEN update_stack       => nstate <= alloc_start;
      -- ----------------------------
      -- ------ ONE CHILD CASE ------
      -- ----------------------------                           
      WHEN read_onechild_wait => nstate <= read_onechild_wait;
                                 IF node_response.done = '1' THEN
                                   nstate <= copydata;
                                 END IF;
      WHEN copydata   => nstate <= wout_start;
      WHEN wout_start => nstate <= wout_wait;
      WHEN wout_wait  => nstate <= wout_wait;
                         IF node_response.done = '1' THEN
                           nstate <= alloc_start;
                         END IF;
      -- ----------------------------
      -- ----------- FREE -----------
      -- ----------------------------  
      WHEN alloc_start => nstate <= alloc_wait;
      WHEN alloc_wait  => nstate <= alloc_wait;
                          IF alloc_in.done = '1' THEN
                            nstate <= alloc_done;
                          END IF;
      WHEN alloc_done => nstate <= balancing;
                         IF saddr0 = 0 THEN
                           nstate <= isdone;
                         END IF;
      WHEN balancing => nstate <= balancing;
                        IF balancing_done_bit = '1' THEN
                          nstate <= isdone;
                        END IF;
      WHEN isdone => nstate <= idle;
      WHEN OTHERS => nstate <= idle;
    END CASE;
  END PROCESS;

  delete_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state               <= nstate;
    alloc_out.start     <= '0';
    node_request.start  <= '0';
    done                <= '0';
    balancing_start_bit <= '0';

    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          flag_succ      <= '0';
          flag_balancing <= '0';
          saddr0         <= 0;
        WHEN checkroot =>
          nowPtr <= rootPtr_IN;
        -- ----------------------------
        -- ------- READ NODE ----------
        -- ----------------------------
        WHEN rnode_start => node_request.start <= '1';
                            node_request.cmd <= rnode;
                            node_request.ptr <= nowPtr;
        WHEN rnode_done => nodeIn <= node_response.node;
        -- ----------------------------
        -- ---- SEARCH: COMPARE KEY ---
        -- ----------------------------
        WHEN comparekey =>
          IF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
            IF nodeIn.leftPtr /= nullPtr THEN
              nowPtr <= nodeIn.leftPtr;
            END IF;
          ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
            IF nodeIn.rightPtr = nullPtr THEN
              nowPtr <= nodeIn.rightPtr;
            END IF;
          ELSIF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
            saddr2update <= saddr0;
            node2update  <= nodeIn;
          END IF;
        -- ----------------------------
        -- ---------- STACK  ----------
        -- ----------------------------
        WHEN write_stack => mystack(saddr0) <= nodeIn;
                            saddr0 <= saddr0 +1;
        -- ----------------------------
        -- ---- FOUND THE KEY! --------
        -- ----------------------------
        WHEN keyfound =>
          IF nodeIn.leftPtr = nullPtr AND nodeIn.rightPtr = nullPtr THEN
            -- if no child
            freePtr <= nodeIn.ptr;
          ELSIF nodeIn.leftPtr /= nullPtr AND nodeIn.rightPtr /= nullPtr THEN
            -- if both children
            nowPtr <= nodeIn.rightPtr;  -- for searching for inorder successor
          ELSE
            -- if only one child
            node_request.start <= '1';
            node_request.cmd   <= rnode;
            node_request.ptr   <= nodeIn.leftPtr;
            IF nodeIn.leftPtr = nullPtr THEN
              node_request.ptr <= nodeIn.rightPtr;
            END IF;
          END IF;
        -- ----------------------------
        -- -- FIND INORDER SUCCESSOR --
        -- ----------------------------
        WHEN succ_ser_compare =>
          IF nodeIn.rightPtr = nullPtr THEN
            freePtr          <= nodeIn.ptr;
            node2update.key  <= nodeIn.key;
            node2update.data <= nodeIn.data;
          ELSE
            nowPtr <= nodeIn.rightPtr;
          END IF;
        WHEN update_stack =>
          mystack(saddr2update) <= node2update;
        -- ----------------------------
        -- ------ ONE CHILD CASE ------
        -- ----------------------------                    
        WHEN copydata => freePtr <= node_response.node.ptr;
                         node2update.key      <= node_response.key;
                         node2update.data     <= node_response.node.data;
                         node2update.leftPtr  <= node_response.node.leftPtr;
                         node2update.rightPtr <= node_response.node.rightPtr;
                         node2update.height   <= node_response.node.height;
        WHEN wout_start => node_request.statr <= '1';
                           node_request.ptr  <= node2update.ptr;
                           node_request.cmd  <= wnode;
                           node_request.node <= node2update;
        -- ----------------------------
        -- ----------- FREE -----------
        -- ----------------------------  
        WHEN alloc_start => alloc_out.start <= '1';
        WHEN alloc_done =>
          IF saddr0 /= 0 THEN
            balancing_start_bit <= '1';
            -- get ready for balancing     
            
          END IF;
        WHEN balancing => flag_balancing <= '1';
        WHEN isdone =>
          done <= '1';
          IF flag_balancing = '0' THEN
            IF node2update.ptr = rootPtr_IN THEN
              rootPtr_OUT <= nullPtr;
            END IF;
          ELSE
            rootPtr_OUT <= returnPtr;
          END IF;
          
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset

  END PROCESS;

  alloc_out.ptr <= freePtr;
  alloc_out.cmd <= free;
END ARCHITECTURE;
