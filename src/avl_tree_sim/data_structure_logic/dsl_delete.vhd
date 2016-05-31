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
  SIGNAL freePtr, returnPtr, nowPtr, updatedPtr  : slv(31 DOWNTO 0);
  SIGNAL succKey                                 : slv(31 DOWNTO 0);
  SIGNAL state, nstate                           : delete_state_type;
  SIGNAL bal_state, bal_nstate                   : delete_bal_state_type;
  SIGNAL node_request, node_request_bal          : node_access_comm_type;
  SIGNAL node_response, node_response_bal        : node_access_comm_type;
  SIGNAL flag_succ, flag_balancing               : STD_LOGIC;
  SIGNAL balancing_start_bit, balancing_done_bit : STD_LOGIC;
  SIGNAL nodeIn, node2update, node2out           : tree_node_type;
  SIGNAL saddr0, saddr1, saddr2update            : INTEGER;
  SIGNAL mystack                                 : stack_type;
  SIGNAL fcase                                   : free_case_type;
  SIGNAL balcase                                 : balancing_case_type;
  SIGNAL chil_balcase                            : balancing_read_children_type;
  SIGNAL balance_factor, child_balance           : INTEGER;
  SIGNAL aNode, bNode, wwNode                    : tree_node_type;
  SIGNAL isMissing                               : missing_child_type;
  SIGNAL ancNode, left_child, right_child        : tree_node_type;
  SIGNAL xNode, yNode, zNode, updatedNode        : tree_node_type;
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
            fcase   <= no_child;
          ELSIF nodeIn.leftPtr /= nullPtr AND nodeIn.rightPtr /= nullPtr THEN
            -- if both children
            nowPtr <= nodeIn.rightPtr;  -- for searching for inorder successor
            fcase  <= both_child;
          ELSE
            -- if only one child
            fcase              <= one_child;
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
            succKey          <= nodeIn.key;
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
            -- no child
            node2bal.ptr        <= nullPtr;
            node2bal.height     <= 0;
            node2bal.leftPtr    <= nullPtr;
            node2bal.rightPtr   <= nullPtr;
            node2bal.key        <= key;
            IF fcase = one_child THEN
              node2bal <= node2update;
            ELSIF fcase = both_child THEN
              node2bal.key <= succKey;
            END IF;
          END IF;
        WHEN balancing => flag_balancing <= '1';
        WHEN isdone =>
          done <= '1';
          IF flag_balancing = '0' THEN
            rootPtr_OUT <= rootPtr_IN;
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

  -- ----------------------------------------------------------
  -- ------------------ BALANCING -----------------------------
  -- ----------------------------------------------------------
  delbal_comb : PROCESS(bal_state, balancing_start_bit, balcase,
                        key, left_child, right_child, saddr1,
                        balance_factor, zNode, isMissing, ancNode,
                        node_response_bal, chil_balcase, child_balance)
    VARIABLE aNode_v, bNode_v : tree_node_type;
  BEGIN
    bal_nstate <= idle;
    CASE bal_state IS
      WHEN idle => bal_nstate <= idle;
                   IF balancing_start_bit = '1' THEN
                     bal_nstate <= read_stack;
                   END IF;
      WHEN ulink => bal_nstate <= cal_bal;
                    IF ancNode.leftPtr /= nullPtr
                      OR ancNode.rightPtr /= nullPtr THEN
                      bal_nstate <= readchild_start;
                    END IF;

      WHEN readchild_start =>
        bal_nstate <= cal_bal;
        IF (isMissing = leftChild AND ancNode.leftPtr /= nullPtr)
          OR (isMissing = rightChild AND ancNode.rightPtr /= nullPtr) THEN
          bal_nstate <= readchild_wait;
        END IF;
        
      WHEN readchild_wait => bal_nstate <= readchild_wait;
                             IF node_response_bal.done = '1' THEN
                               bal_nstate <= cal_bal;
                             END IF;
      WHEN cal_bal => bal_nstate <= check_bal;
      WHEN check_bal =>
        bal_nstate <= w_start;
        IF balance_factor > 1 THEN
          bal_nstate <= chil_rnode1;
          IF left_child.leftPtr = nullPtr THEN
            bal_nstate <= chil_rnode2;
          END IF;
        ELSIF balance_factor < -1 THEN
          bal_nstate <= chil_rnode1;
          IF right_child.leftPtr = nullPtr THEN
            bal_nstate <= chil_rnode2;
          END IF;
        END IF;
      -- -----------------------------
      -- -- ROTATION DECISION (NEW) --
      -- -----------------------------
      WHEN chil_rnode1 => bal_nstate <= chil_rnode1;
                          IF node_response_bal.done = '1' THEN
                            bal_nstate <= chil_rnode2;
                          END IF;
      WHEN chil_rnode2 =>
        bal_nstate <= chil_rnode3;
        IF balance_factor > 1 AND left_child.rightPtr = nullPtr THEN
          bal_nstate <= chil_calc_bal;
        ELSIF balance_factor < -1 AND right_child.rightPtr = nullPtr THEN
          bal_nstate <= chil_calc_bal;
        END IF;
      WHEN chil_rnode3 => bal_nstate <= chil_rnode3;
                          IF node_response_bal.done = '1' THEN
                            bal_nstate <= chil_rnode4;
                          END IF;
      WHEN chil_rnode4   => bal_nstate <= chil_calc_bal;
      WHEN chil_calc_bal => nstate     <= chil_check_bal;
      WHEN chil_check_bal =>
        nstate <= r1;                   -- A                               
        IF chil_balcase = rightones THEN
          nstate <= l1;                 -- B
          IF child_balance THEN
            nstate <= d_prep_wait;      -- D
          END IF;
        ELSE
          IF child_balance < 0 THEN     -- C
            nstate <= c_prep_wait;
          END IF;
        END IF;
      -- -----------------------------
      -- ------ write out -------
      -- -----------------------------
      WHEN w_start => bal_nstate <= w_wait;
      WHEN w_wait  => bal_nstate <= w_wait;
                      IF node_response_bal.done = '1' THEN
                        bal_nstate <= read_stack;
                      END IF;
      -- -----------------------------
      -- ------ RIGHT ROTATION -------
      -- -----------------------------
      WHEN r1 => bal_nstate <= r2;
                 IF zNode.leftPtr = nullPtr THEN
                   bal_nstate <= r3;
                 END IF;
      WHEN r2 => bal_nstate <= r2;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= r3;
                 END IF;
      WHEN r3 => bal_nstate <= r4;
                 IF zNode.rightPtr = nullPtr THEN
                   bal_nstate <= r6;
                 END IF;
      WHEN r4 => bal_nstate <= r4;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= r5;
                 END IF;
      WHEN r5 => bal_nstate <= r6;
      WHEN r6 => bal_nstate <= r7;
      WHEN r7 => bal_nstate <= r8;
      WHEN r8 => bal_nstate <= r8;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= r9;
                 END IF;
      WHEN r9  => bal_nstate <= r10;
      WHEN r10 => bal_nstate <= r10;
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
                 IF zNode.leftPtr = nullPtr THEN
                   bal_nstate <= l3;
                 END IF;
      WHEN l2 => bal_nstate <= l2;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= l3;
                 END IF;
      WHEN l3 => bal_nstate <= l4;
                 IF zNode.rightPtr = nullPtr THEN
                   bal_nstate <= l6;
                 END IF;
      WHEN l4 => bal_nstate <= l4;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= l5;
                 END IF;
      WHEN l5 => bal_nstate <= l6;
      WHEN l6 => bal_nstate <= l7;
      WHEN l7 => bal_nstate <= l8;
      WHEN l8 => bal_nstate <= l8;
                 IF node_response_bal.done = '1' THEN
                   bal_nstate <= l9;
                 END IF;
      WHEN l9  => bal_nstate <= l10;
      WHEN l10 => bal_nstate <= l10;
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
                            bal_nstate <= c_prep_sec;
                          END IF;
      WHEN c_prep_sec => bal_nstate <= c_prep_wait2;
                         IF left_child.leftPtr = nullPtr THEN
                           bal_nstate <= l1;
                         END IF;
      WHEN c_prep_wait2 => bal_nstate <= c_prep_wait2;
                           IF node_response_bal.done = '1' THEN
                             bal_nstate <= c_prep_done;
                           END IF;
      WHEN c_prep_done => bal_nstate <= l1;
      WHEN d_prep_wait => bal_nstate <= d_prep_wait;
                          IF node_response_bal.done = '1' THEN
                            bal_nstate <= d_prep_sec;
                          END IF;
      WHEN d_prep_sec => bal_nstate <= d_prep_wait2;
                         IF right_child.rightPtr = nullPtr THEN
                           bal_nstate <= r1;
                         END IF;
      WHEN d_prep_wait2 => bal_nstate <= d_prep_wait2;
                           IF node_response_bal.done = '1' THEN
                             bal_nstate <= d_prep_done;
                           END IF;
      WHEN d_prep_done => bal_nstate <= r1;
      WHEN drcheck     => bal_nstate <= r1;
                          IF balcase = D THEN
                            bal_nstate <= l1;
                          END IF;
      WHEN rotation_done => bal_nstate <= read_stack;
                            IF saddr1 = 0 THEN
                              bal_nstate <= isdone;
                            END IF;
      WHEN read_stack => bal_nstate <= ulink;
                         IF saddr1 = 0 THEN
                           bal_nstate <= isdone;
                         END IF;
      WHEN isdone => bal_nstate <= idle;
      WHEN OTHERS => bal_nstate <= idle;
    END CASE;
    
  END PROCESS;

  delbal_reg : PROCESS
    VARIABLE node_v : tree_node_type;
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
          -- ancNode     <= NodeIn;
          saddr1      <= saddr0;
          updatedPtr  <= node2out.ptr;
          updatedNode <= node2out;
          IF fcase = both_child THEN
            keyRef <= succKey;
          ELSE
            keyRef <= key;
          END IF;
        WHEN ulink =>
          IF to_integer(uns(keyRef)) < to_integer(uns(ancNode.key)) THEN
            ancNode.leftPtr <= updatedPtr;
            left_child      <= updatedNode;
            isMissing       <= rightChild;

            right_child.height <= 0;
            right_child.ptr    <= nullPtr;
          ELSE
            ancNode.rightPtr <= updatedPtr;
            right_child      <= updatedNode;
            isMissing        <= leftChild;

            left_child.height <= 0;
            left_child.ptr    <= nullPtr;
          END IF;
        WHEN readchild_start =>
          IF to_integer(uns(keyRef)) < to_integer(uns(ancNode.key)) THEN
            IF ancNode.rightPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= ancNode.rightPtr;
              node_request_bal.cmd   <= rnode;
            END IF;
          ELSE
            IF ancNode.leftPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= ancNode.leftPtr;
              node_request_bal.cmd   <= rnode;
            END IF;
          END IF;
        WHEN cal_bal =>
          IF isMissing = rightChild THEN
            ancNode.height <= MAXIMUM(left_child.height, right_child.height)+1;
            balance_factor <= left_child.height - right_child.height;
            IF ancNode.rightPtr /= nullPtr THEN
              right_child    <= node_response_bal.node;
              ancNode.height <= MAXIMUM(left_child.height, node_response_bal.node.height)+1;
              balance_factor <= left_child.height - node_response_bal.node.height;
            END IF;
          ELSE
            ancNode.height <= MAXIMUM(left_child.height, right_child.height)+1;
            balance_factor <= left_child.height - right_child.height;
            IF ancNode.leftPtr /= nullPtr THEN
              left_child     <= node_response_bal.node;
              ancNode.height <= MAXIMUM(node_response_bal.node.height, right_child.height)+1;
              balance_factor <= node_response_bal.node.height - right_child.height;
            END IF;
          END IF;
        WHEN check_bal =>
          IF balance_factor > 1 THEN        -- left balance
            chil_balcase <= leftones;
            IF left_child.leftPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= left_child.leftPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              height_left <= 0;
            END IF;
          ELSIF balance_factor < -1 THEN    -- right balance
            chil_balcase <= rightones;
            IF right_child.leftPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= right_child.leftPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              height_left <= 0;
            END IF;
          END IF;
        -- -----------------------------
        -- -- ROTATION DECISION (NEW) --
        -- -----------------------------          
        WHEN chil_rnode2 =>
          IF chil_balcase = leftones THEN
            IF left_child.leftPtr /= nullPtr THEN
              height_left <= node_response_bal.node.height;
            END IF;
            IF left_child.rightPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= left_child.rightPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              height_right <= 0;
            END IF;
          ELSE
            IF right_child.leftPtr /= nullPtr THEN
              height_left <= node_response_bal.node.height;
            END IF;
            IF right_child.rightPtr /= nullPtr THEN
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= right_child.rightPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              height_right <= 0;
            END IF;
          END IF;
        WHEN chil_rnode4 =>
          hright_right <= node_response_bal.node.height;
        WHEN chil_calc_bal =>
          child_balance <= height_left - height_right;
        WHEN chil_check_bal =>
          IF chil_balcase = leftones THEN
            IF child_balance < 0 THEN
              balcase                <= C;  -- C
              -- left right
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= left_child.rightPtr;
              node_request_bal.cmd   <= rnode;
              
            ELSE
              balcase <= A;                 -- A
              -- RIGHT ROTATE
              yNode   <= ancNode;
              zNode   <= left_child;
              wwNode  <= right_child;
            END IF;
          ELSE
            IF child_balance > 0 THEN
              balcase                <= D;  -- D
              -- right left
              node_request_bal.start <= '1';
              node_request_bal.ptr   <= right_child.leftPtr;
              node_request_bal.cmd   <= rnode;
            ELSE
              balcase <= B;                 -- B
              -- LEFT ROTATE
              xNode   <= ancNode;
              zNode   <= right_child;
              wwNode  <= left_child;
              balcase <= B;
            END IF;
          END IF;
        -- -----------------------------
        -- -- write --
        -- -----------------------------         
        WHEN w_start =>
          node_request_bal.start <= '1';
          node_request_bal.ptr   <= ancNode.ptr;
          node_request_bal.node  <= ancNode;
          node_request_bal.cmd   <= wnode;
          --?
          returnPtr              <= ancNode.ptr;
          updatedNode            <= ancNode;
          updatedPtr             <= ancNode.ptr;
        WHEN c_prep_sec=>
          -- LEFT ROTATE
          xNode <= left_child;
          zNode <= node_response_bal.node;
          -- getting wnode (left child of the leftchild of orig node)
          IF left_child.leftPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.ptr   <= left_child.leftPtr;
            node_request_bal.cmd   <= rnode;
          ELSE
            wwNode.height <= 0;
            wwNode.ptr    <= nullPtr;
          END IF;
        WHEN d_prep_sec =>
          -- RIGHT ROTATE
          yNode <= right_child;
          zNode <= node_response_bal.node;
          IF right_child.rightPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.ptr   <= right_child.rightPtr;
            node_request_bal.cmd   <= rnode;
          ELSE
            wwNode.height <= 0;
            wwNode.ptr    <= nullPtr;
          END IF;
        WHEN c_prep_done => wwNode <= node_response_bal.node;
        WHEN d_prep_done => wwNode <= node_response_bal.node;
        WHEN drcheck =>
          IF balcase = C THEN
            yNode.ptr      <= ancNode.ptr;
            yNode.key      <= ancNode.key;
            yNode.data     <= ancNode.data;
            yNode.leftPtr  <= updatedPtr;   -- ROTATION RESULT
            yNode.rightPtr <= ancNode.rightPtr;
            yNode.height   <= ancNode.height;
            zNode          <= updatedNode;  -- left_child; -- has changed
            wwNode         <= right_child;
          ELSIF balcase = D THEN
            xNode.ptr      <= ancNode.ptr;
            xNode.key      <= ancNode.key;
            xNode.data     <= ancNode.data;
            xNode.leftPtr  <= ancNode.leftPtr;
            xNode.rightPtr <= updatedPtr;   -- ROTATION RESULT
            xNode.height   <= ancNode.height;
            zNode          <= updatedNode;  --right_child; -- has changed
            wwNode         <= left_child;
          END IF;
        -- -----------------------------
        -- ------ RIGHT ROTATION -------
        -- -----------------------------
        WHEN r1 =>
          IF zNode.leftPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.cmd   <= rnode;
            node_request_bal.ptr   <= zNode.leftPtr;
          ELSE
            aNode.height <= 0;
            aNode.ptr    <= nullPtr;
          END IF;
        WHEN r3 =>
          IF zNode.leftPtr /= nullPtr THEN
            aNode <= node_response_bal.node;
          END IF;
          IF zNode.rightPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.cmd   <= rnode;
            node_request_bal.ptr   <= zNode.rightPtr;
          ELSE
            bNode.height <= 0;
            bNode.ptr    <= nullPtr;
          END IF;
        WHEN r5 =>
          IF zNode.rightPtr /= nullPtr THEN
            bNode <= node_response_bal.node;
          END IF;
        WHEN r6 =>                          -- ROTATION STUFF
          xNode.ptr     <= zNode.ptr;
          xNode.leftPtr <= zNode.leftPtr;
          xNode.key     <= zNode.key;
          xNode.data    <= zNode.data;

          xNode.rightPtr <= yNode.ptr;
          yNode.leftPtr  <= bNode.ptr;
          yNode.height   <= MAXIMUM(bNode.height, wwNode.height)+1;
        WHEN r7 =>
          xNode.height <= MAXIMUM(aNode.height, yNode.height)+1;  -- updated height of node to be returned

          node_request_bal.start <= '1';
          node_request_bal.cmd   <= wnode;
          node_request_bal.ptr   <= yNode.ptr;
          node_request_bal.node  <= yNode;
        WHEN r9 =>
          node_request_bal.start <= '1';
          node_request_bal.cmd   <= wnode;
          node_request_bal.ptr   <= xNode.ptr;
          node_request_bal.node  <= xNode;
          updatedPtr             <= xNode.ptr;
          updatedNode            <= xNode;
          returnPtr              <= xNode.ptr;
        -- -----------------------------
        -- ------ LEFT ROTATION --------
        -- -----------------------------
        WHEN l1 =>
          IF zNode.leftPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.cmd   <= rnode;
            node_request_bal.ptr   <= zNode.leftPtr;
          ELSE
            aNode.height <= 0;
            aNode.ptr    <= nullPtr;
          END IF;
        WHEN l3 =>
          IF zNode.leftPtr /= nullPtr THEN
            aNode <= node_response_bal.node;
          END IF;
          IF zNode.rightPtr /= nullPtr THEN
            node_request_bal.start <= '1';
            node_request_bal.cmd   <= rnode;
            node_request_bal.ptr   <= zNode.rightPtr;
          ELSE
            bNode.height <= 0;
            bNode.ptr    <= nullPtr;
          END IF;
        WHEN l5 =>
          IF zNode.rightPtr /= nullPtr THEN
            bNode <= node_response_bal.node;
          END IF;
        WHEN l6 =>                      -- ROTATION STUFF
          yNode.ptr      <= zNode.ptr;
          yNode.rightPtr <= zNode.rightPtr;
          yNode.key      <= zNode.key;
          yNode.data     <= zNode.data;

          yNode.leftPtr  <= xNode.ptr;
          xNode.rightPtr <= aNode.ptr;
          xNode.height   <= MAXIMUM(wwNode.height, aNode.height)+1;
          
        WHEN l7 =>
          yNode.height <= MAXIMUM(xNode.height, bNode.height)+1;  -- updated height of node to be returned

          node_request_bal.start <= '1';
          node_request_bal.cmd   <= wnode;
          node_request_bal.ptr   <= xNode.ptr;
          node_request_bal.node  <= xNode;

        WHEN l9 =>
          node_request_bal.start <= '1';
          node_request_bal.cmd   <= wnode;
          node_request_bal.ptr   <= yNode.ptr;
          node_request_bal.node  <= yNode;
          updatedPtr             <= yNode.ptr;
          updatedNode            <= yNode;
          returnPtr              <= yNode.ptr;
        -- -----------------------------
        -- --------- READ STACK --------
        -- -----------------------------
        WHEN read_stack =>
          IF saddr1 /= 0 THEN
            ancNode <= mystack(saddr1-1);
            node_v  <= mystack(saddr1-1);
            saddr1  <= saddr1 - 1;
          END IF;
        WHEN isdone => balancing_done_bit <= '1';
        WHEN OTHERS => NULL;
      END CASE;

    END IF;  -- if reset

  END PROCESS;

-- ----------------------------------------------------------
-- ------------------ ACCESS ARBITRATOR ---------------------
-- ----------------------------------------------------------
  acc_comb_del : PROCESS(state, node_request_bal, node_request, node_response_port)
  BEGIN
    node_request_port <= node_request;
    IF state = balancing THEN
      node_request_port <= node_request_bal;
    END IF;
    node_response.ptr               <= (OTHERS => '0');
    node_response_bal.ptr           <= (OTHERS => '0');
    node_response.cmd               <= rnode;
    node_response_bal.cmd           <= rnode;
    node_response.start             <= '0';
    node_response_bal.start         <= '0';
    node_response.done              <= '0';
    node_response.done              <= '0';
    node_response.node.ptr          <= (OTHERS => '0');
    node_response.node.key          <= (OTHERS => '0');
    node_response.node.data         <= (OTHERS => '0');
    node_response.node.leftPtr      <= (OTHERS => '0');
    node_response.node.rightPtr     <= (OTHERS => '0');
    node_response.node.height       <= 0;
    node_response_bal.node.ptr      <= (OTHERS => '0');
    node_response_bal.node.key      <= (OTHERS => '0');
    node_response_bal.node.data     <= (OTHERS => '0');
    node_response_bal.node.leftPtr  <= (OTHERS => '0');
    node_response_bal.node.rightPtr <= (OTHERS => '0');
    node_response_bal.node.height   <= 0;
    IF state = balancing THEN
      node_response_bal <= node_response_port;
    ELSE
      node_response <= node_response_port;
    END IF;
  END PROCESS;

  alloc_out.ptr <= freePtr;
  alloc_out.cmd <= free;
END ARCHITECTURE;
