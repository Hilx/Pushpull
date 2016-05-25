LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_insert IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    -- root
    rootPtr_IN    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    rootPtr_OUT   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- control
    start         : IN  STD_LOGIC;
    done          : OUT STD_LOGIC;
    -- item
    key           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- node access
    node_request  : OUT node_access_comm_type;
    node_response : IN  node_access_comm_type;
    -- allocator
    alloc_in      : IN  allocator_com_type;
    alloc_out     : OUT allocator_com_type
    );
END ENTITY dsl_insert;

ARCHITECTURE syn_dsl_insert OF dsl_insert IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate                    : insert_state_type;
  SIGNAL bal_state, bal_nstate            : insert_bal_state_type;
  SIGNAL rootPtr, nowPtr                  : slv(31 DOWNTO 0);
  SIGNAL flag_stack_end                   : STD_LOGIC;
  SIGNAL balancing_done_bit               : STD_LOGIC;
  SIGNAL balancing_start_bit              : STD_LOGIC;
  SIGNAL node_request_bal                 : node_access_comm_type;
  SIGNAL node_response_bal                : node_access_comm_type;
  SIGNAL flag_end_of_stack                : STD_LOGIC;
  SIGNAL balcase                          : balancing_case_type;
  SIGNAL balance_factor                   : SIGNED(31 DOWNTO 0);
  SIGNAL newNode, nodeIn                  : tree_node_type;
  SIGNAL ancNode, left_child, right_child : tree_node_type;
  SIGNAL isMissing                        : missing_child_type;
  SIGNAL xNode, yNode, zNode              : tree_node_type;
  SIGNAL updatedPtr                       : slv(31 DOWNTO 0);
  SIGNAL saddr0, saddr1                   : INTEGER;
  SIGNAL mystack                          : stack_type;
BEGIN
  -- ----------------------------------------------------------
  -- --------------- INSERT SEARCH AND ALLOCATE ---------------
  -- ----------------------------------------------------------
  ins_comb : PROCESS(state, start, key, node_response, alloc_in,
                     rootPtr_IN, nodeIn, flag_stack_end,
                     balancing_done_bit)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF start = '1' THEN
                     nstate <= checkroot;
                   END IF;
      WHEN checkroot => nstate <= rnode_start;
                        IF rootPtr_IN = nullPtr THEN
                          nstate <= alloc_start;
                        END IF;
      WHEN rnode_start => nstate <= rnode_wait;
      WHEN rnode_wait  => nstate <= rnode_wait;
                          IF node_response.done = '1' THEN
                            nstate <= rnode_done;
                          END IF;
      WHEN rnode_done  => nstate <= comparekey;
      WHEN alloc_start => nstate <= alloc_wait;
      WHEN alloc_wait  => nstate <= alloc_wait;
                          IF alloc_in.done = '1' THEN
                            nstate <= alloc_done;
                          END IF;
      WHEN alloc_done => nstate <= wnew_start;
      WHEN wnew_start => nstate <= wnew_wait;
      WHEN wnew_wait  => nstate <= wnew_wait;
                         IF node_response.done = '1' THEN
                           nstate <= wnew_done;
                         END IF;
      WHEN wnew_done => nstate <= balancing;
                        IF rootPtr_IN = nullPtr THEN
                          nstate <= isdone;
                        END IF;
      WHEN balancing => nstate <= balancing;
                        IF balancing_done_bit = '1' THEN
                          nstate <= isdone;
                        END IF;
      WHEN comparekey =>
        nstate <= write_stack;
        IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
          nstate <= isdone;
        ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.leftPtr = nullPtr THEN
            nstate <= alloc_start;
          END IF;
        ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.rightPtr = nullPtr THEN
            nstate <= alloc_start;
          END IF;
        END IF;
      WHEN write_stack => nstate <= rnode_start;
      WHEN isdone      => nstate <= idle;
      WHEN OTHERS      => nstate <= idle;
    END CASE;

  END PROCESS;

  ins_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state               <= nstate;
    done                <= '0';
    alloc_out.start     <= '0';
    node_request.start  <= '0';
    balancing_start_bit <= '1';
    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          flag_stack_end <= '0';
          saddr0         <= 0;
        WHEN checkroot =>
          rootPtr          <= rootPtr_IN;
          nowPtr           <= rootPtr_IN;
          node_request.ptr <= rootPtr_IN;
        WHEN write_stack =>
          mystack(saddr0) <= nodeIn;
          saddr0          <= saddr0 + 1;
        WHEN alloc_start =>
          alloc_out.start  <= '1';
          newNode.key      <= key;
          newNode.data     <= data;
          newNode.height   <= 1;
          newNode.leftPtr  <= nullPtr;
          newNode.rightPtr <= nullPtr;
        WHEN alloc_done =>
          newNode.ptr <= alloc_in.ptr;
        WHEN wnew_start=>
          node_request.ptr   <= newNode.ptr;
          node_request.node  <= newNode;
          node_request.start <= '1';
          node_request.cmd   <= wnode;
        WHEN wnew_done =>
          balancing_start_bit <= '1';
        WHEN rnode_start=>
          node_request.start <= '1';
          node_request.cmd   <= rnode;
        WHEN rnode_done =>
          nodeIn <= node_response.node;
        WHEN isdone =>
          done <= '1';
          -- root ptr may be updated due to balancing as well
          -- code will be added later!
          IF rootPtr_IN = nullPtr THEN
            rootPtr_OUT <= newNode.ptr;
          END IF;
          
        WHEN OTHERS => NULL;
      END CASE;
      
    END IF;  -- if reset 

  END PROCESS;

  -- ----------------------------------------------------------
  -- ------------------ BALANCING -----------------------------
  -- ----------------------------------------------------------
  insbal_comb : PROCESS(bal_state, balancing_start_bit, balcase,
                        key, left_child, right_child,
                        node_response_bal)
  BEGIN
    bal_nstate <= idle;
    CASE bal_state IS
      WHEN idle => bal_nstate <= idle;
                   IF balancing_start_bit = '1' THEN
                     bal_nstate <= ulink;
                   END IF;
      WHEN ulink          => bal_nstate <= readchild_wait;
      WHEN readchild_wait => bal_nstate <= readchild_wait;
                             IF node_response_bal.done = '1' THEN
                               bal_nstate <= cal_bal;
                             END IF;
      WHEN cal_bal => bal_nstate <= check_bal;
      WHEN check_bal =>
        bal_nstate <= w_start;
        IF balance_factor > 1 AND key < left_child.key THEN       -- A
          bal_nstate <= r1;
        ELSIF balance_factor < -1 AND key > right_child.key THEN  -- B
          bal_nstate <= l1;
        ELSIF balance_factor > 1 AND key > left_child.key THEN    -- C
          bal_nstate <= c_prep_wait;
        ELSIF balance_factor < -1 AND key < right_child.key THEN  -- D
          bal_nstate <= d_prep_wait;
        END IF;
      WHEN w_start => bal_nstate <= w_wait;
      WHEN w_wait  => bal_nstate <= w_wait;
                      IF node_response_bal.done = '1' THEN
                        bal_nstate <= read_stack;
                      END IF;
      -- -----------------------------
      -- ------ RIGHT ROTATION -------
      -- -----------------------------
      WHEN r1 => bal_nstate <= r2;
      WHEN r2 => bal_nstate <= r3;
      WHEN r3 => bal_nstate <= r3;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= r4;
                 END IF;
      WHEN r4 => bal_nstate <= r5;
      WHEN r5 => bal_nstate <= r6;
      WHEN r6 => bal_nstate <= r6;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= r7;
                 END IF;
      WHEN r7 => bal_nstate <= r8;
      WHEN r8 => bal_nstate <= r8;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= rotation_done;
                   IF balcase = D THEN
                     bal_nstate <= drcheck;
                   END IF;
                 END IF;
      -- -----------------------------
      -- ------ LEFT ROTATION --------
      -- -----------------------------
      WHEN l1 => bal_nstate <= l2;
      WHEN l2 => bal_nstate <= l3;
      WHEN l3 => bal_nstate <= l3;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= l4;
                 END IF;
      WHEN l4 => bal_nstate <= l5;
      WHEN l5 => bal_nstate <= l6;
      WHEN l6 => bal_nstate <= l6;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= l7;
                 END IF;
      WHEN l7 => bal_nstate <= l8;
      WHEN l8 => bal_nstate <= l8;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= rotation_done;
                   IF balcase = C THEN
                     bal_nstate <= drcheck;
                   END IF;
                 END IF;

      -- -----------------------------
      -- --- Double Rotation Pause ---
      -- -----------------------------
      WHEN c_prep_wait => bal_nstate <= c_prep_wait;
                          IF node_response_bal.done = '1' THEN
                            bal_nstate <= c_prep_done;
                          END IF;
      WHEN c_prep_done => nstate     <= l1;
      WHEN d_prep_wait => bal_nstate <= d_prep_wait;
                          IF node_response_bal.done = '1' THEN
                            bal_nstate <= d_prep_done;
                          END IF;
      WHEN d_prep_done => nstate     <= r1;
      WHEN drcheck     => bal_nstate <= r1;
                          IF balcase = D THEN
                            bal_nstate <= l1;
                          END IF;
      WHEN rotation_done => bal_nstate <= read_stack;
                            IF saddr1 = 0 THEN
                              bal_nstate <= isdone;
                            END IF;
      WHEN read_stack => bal_nstate <= ulink;
      WHEN isdone     => bal_nstate <= idle;
      WHEN OTHERS     => bal_nstate <= idle;
    END CASE;
    
  END PROCESS;

  insbal_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    bal_state              <= bal_nstate;
    balancing_done_bit     <= '0';
    node_request_bal.start <= '0';
    IF rst = CONST_RESET THEN
      bal_state <= idle;
    ELSE
      CASE bal_state IS
        WHEN idle =>
          ancNode <= NodeIn;
          saddr1  <= saddr0;
        WHEN ulink =>
          IF to_integer(uns(key)) < ancNode.key THEN
            ancNode.leftPtr    <= newNode.ptr;
            left_child         <= newNode;
            missing_child_type <= rightChild;
            -- reading missing child
            IF ancNode.rightPter /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= ancNode.rightPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              right_child.height <= 0;
            END IF;
          ELSE
            ancNode.rightPtr   <= newNode.ptr;
            right_child        <= newNode;
            missing_child_type <= leftChild;
            -- reading missing child
            IF ancNode.leftPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= ancNode.leftPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              left_child.height <= 0;
            END IF;
          END IF;
        WHEN cal_bal =>
          IF isMissing = rightChild THEN
            IF ancNode.rightPtr /= nullPtr THEN
              right_child <= node_response_bal.node;
            END IF;
            ancNode.height <= slv(to_unsigned(
              MAXIMUM(left_child.height, node_response_bal.node.height)+1),32);
            balance_factor <= SIGNED(left_child.height)
                              - SIGNED(node_response_bal.node.height);
          ELSE
            IF ancNode.leftPtr /= nullPtr THEN
              left_child <= node_response_bal.node;
            END IF;
            ancNode.height <= slv(to_unsigned(
              MAXIMUM(node_response_bal.node.height, right_child.height)+1),32);
            balance_factor <= SIGNED(node_response_bal.node.height)
                              - SIGNED(right_child.height);
          END IF;
        WHEN check_bal =>
          IF balance_factor > 1 AND key < left_child.key THEN       -- A
            -- RIGHT ROTATE
            yNode     <= ancNode;
            zNode     <= left_child;
            isMissing <= A;
          ELSIF balance_factor < -1 AND key > right_child.key THEN  -- B
            -- LEFT ROTATE
            xNode     <= ancNode;
            zNode     <= right_child;
            isMissing <= B;
          ELSIF balance_factor > 1 AND key > left_child.key THEN    -- C
            node_request_bal.start <= '1';
            node_request_bal.ptr   <= left_child.rightPtr;
            node_request_bal.cmd   <= rnode;
            isMissing              <= C;
          ELSIF balance_factor < -1 AND key < right_child.key THEN  -- D
            node_request_bal.start <= '1';
            node_request_bal.ptr   <= right_child.leftPtr;
            node_request_bal.cmd   <= rnode;
            isMissing              <= D;
          END IF;
        WHEN w_start =>
          node_request_bal.start <= '1';
          node_request_bal.ptr   <= ancNode.ptr;
          node_request_bal.node  <= ancNode;
          node_request_bal.cmd   <= wnode;
        WHEN c_prep_done =>
          -- LEFT ROTATE
          xNode <= left_child;
          zNode <= node_response_bal.node;
        WHEN d_prep_done=>
          -- RIGHT ROTATE
          yNode <= right_child;
          zNode <= node_response_bal.node;
        WHEN drcheck =>
          IF isMissing = C THEN
            yNode.ptr      <= ancNode.ptr;
            yNode.key      <= ancNode.key;
            yNode.data     <= ancNode.data;
            yNode.leftPtr  <= updatedPtr;  -- ROTATION RESULT
            yNode.rightPtr <= ancNode.rightPtr;
            yNode.height   <= ancNode.height;
            zNode          <= left_child;
          ELSIF isMissing = D THEN
            xNode.ptr      <= ancNode.ptr;
            xNode.key      <= ancNode.key;
            xNode.data     <= ancNode.data;
            xNode.leftPtr  <= ancNode.leftPtr;
            xNode.rightPtr <= updatedPtr;  -- ROTATION RESULT
            xNode.height   <= ancNode.height;
            zNode          <= right_child;
          END IF;
        WHEN read_stack =>
          ancNode <= mystack(saddr1-1);
          saddr1  <= saddr1 - 1;
        WHEN isdone => balancing_done_bit <= '1';
        WHEN OTHERS => NULL;
      END CASE;

    END IF;  -- if reset

  END PROCESS;

  -- ----------------------------------------------------------
  -- ------------------ ACCESS ARBITRATOR ---------------------
  -- ----------------------------------------------------------

END ARCHITECTURE;
