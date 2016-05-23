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
  SIGNAL state, nstate   : insert_state_type;
  SIGNAL rootPtr, nowPtr : slv(31 DOWNTO 0);
  SIGNAL flag_stack_end  : STD_LOGIC;
BEGIN
  
  ins_comb : PROCESS(state, start, key, node_response, alloc_in,
                     rootPtr_IN, nodeIn, flag_stack_end)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle =>
        nstate <= idle;
        IF start = '1' THEN
          nstate <= checkroot;
        END IF;
      WHEN checkroot =>
        nstate <= rnode_start;
        IF rootPtr_IN = nullPtr THEN
          nstate <= alloc_start;
        END IF;
      WHEN rnode_start =>
        nstate <= rnode_wait;
      WHEN rnode_wait =>
        nstate <= rnode_wait;
        IF node_response.done = '1' THEN
          nstate <= rnode_done;
        END IF;
      WHEN rnode_done =>
        nstate <= comparekey;
      WHEN alloc_start =>
        nstate <= alloc_wait;
      WHEN alloc_wait =>
        nstate <= alloc_wait;
        IF alloc_in.done = '1' THEN
          nstate <= alloc_done;
        END IF;
      WHEN alloc_done =>
        nstate <= wnew_start;
      WHEN wnew_start=>
        nstate <= wnew_wait;
      WHEN wnew_wait =>
        nstate <= wnew_wait;
        IF node_response.done = '1' THEN
          nstate <= wnew_done;
        END IF;
      WHEN wnew_done =>
        nstate <= par_update;
        IF rootPtr_IN = nullPtr THEN
          nstate <= isdone;
        END IF;
      WHEN comparekey =>
        nstate <= rnode_start;
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
      WHEN par_update=>
        nstate <= par_balance;
      WHEN par_balance =>
        nstate <= stack_read;
      WHEN stack_read=>
        nstate <= balance_node;
      WHEN balance_node =>
        nstate <= stack_read;
        IF flag_stack_end = '1' THEN
          nstate <= isdone;
        END IF;
      WHEN isdone => nstate <= idle;
      WHEN OTHERS => nstate <= idle;
    END CASE;

  END PROCESS;

  ins_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state              <= nstate;
    done               <= '0';
    alloc_out.start    <= '0';
    node_request.start <= '0';
    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          flag_stack_end <= '0';
        WHEN checkroot =>
          rootPtr          <= rootPtr_IN;
          nowPtr           <= rootPtr_IN;
          node_request.ptr <= rootPtr_IN;
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
        WHEN rnode_start=>
          node_request.start <= '1';
          node_request.cmd   <= rnode;
        WHEN rnode_done =>
          nodeIn <= node_response.node;
        WHEN par_update =>
          -- HOW ABOUT HEIGHT?
          IF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
            nodeIn.leftPtr <= alloc_in.ptr;
          ELSE
            nodeIn.rightPtr <= alloc_in.ptr;
          END IF;
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
  
END ARCHITECTURE;
