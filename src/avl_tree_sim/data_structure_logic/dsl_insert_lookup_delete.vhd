LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_ild IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    rootPtr_IN    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    rootPtr_OUT   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    --
    start         : IN  STD_LOGIC;
    cmd           : IN  dsl_cmd_type;
    done          : OUT STD_LOGIC;
    key           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    data          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    lookup_result : OUT dsl_lookup_result_type;  -- data and if data is valid
    -- node access
    node_request  : OUT node_access_comm_type;
    node_response : IN  node_access_comm_type;
    --
    alloc_in      : IN  allocator_com_type;
    alloc_out     : OUT allocator_com_type;
    --
    mcin          : IN  mem_control_type;
    mcout         : OUT mem_control_type
    );
END ENTITY dsl_ild;

ARCHITECTURE syn_dsl_ild OF dsl_ild IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate      : dsl_ild_state_type;
  SIGNAL rootPtr            : slv(31 DOWNTO 0);
  SIGNAL flag_creating_root : STD_LOGIC;
  SIGNAL flag_new_node      : STD_LOGIC;
  SIGNAL flag_pupdating     : STD_LOGIC;
  SIGNAL flag_left_create   : STD_LOGIC;
  
BEGIN
  ild_fsm_comb : PROCESS(state, start, cmd, key, node_response, alloc_in)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle =>
        nstate <= idle;
        IF start = '1' THEN
          nstate <= root_check;
        END IF;
      -- -----------------------
      -- begining
      -- -----------------------
      WHEN root_check =>
        nstate <= rnode_start;
        IF rootPtr = nullPtr THEN
          nstate <= isdone;
          IF cmd = insert THEN
            nstate <= nalloc_start;
          END IF;
        END IF;
      -- -----------------------
      -- read node
      -- -----------------------     
      WHEN rnode_start =>
        nstate <= rnode_wait;
      WHEN rnode_wait =>
        nstate <= rnode_wait;
        IF node_response.done = '1' THEN
          nstate <= rnode_done;
        END IF;
      WHEN rnode_done =>
        nstate <= compare;
      -- -----------------------
      -- write node
      -- -----------------------     
      WHEN wnode_start =>
        nstate <= wnode_wait;
      WHEN wnode_wait =>
        nstate <= wnode_wait;
        IF node_response.done = '1' THEN
          nstate <= wnode_done;
        END IF;
      WHEN wnode_done =>
        nstate <=;                      -- ?
        IF flag_new_node = '1' THEN
          nstate <= pupdate_start;
          IF flag_creating_root = '1' THEN
            nstate <= isdone;
          END IF;
        END IF;
        IF flag_pupdating = '1' THEN
          nstate <= balance_start;
        END IF;


      -- -----------------------
      -- compare
      -- ----------------------
      WHEN compare =>
        nstate <= rnode;
        IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
          IF cmd = insert OR cmd = lookup THEN
            nstate <= isdone;
          ELSIF cmd = delete THEN
            nstate <= deletion;         -- for now
          END IF;
        ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
          -- if key < key_in
          IF nodeIn.leftPtr == nullPtr THEN
            nstate <= isdone;           -- if cmd = lookup or delete
            IF cmd = insert THEN
              nstate <= nalloc_start;
            END IF;
          END IF;
        ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
          -- if key > key_in
          IF nodeIn.rightPtr == nullPtr THEN
            nstate <= isdone;           -- if cmd = lookup or delete
            IF cmd = insert THEN
              nstate <= nalloc_start;
            END IF;
          END IF;
        END IF;
      -- -----------------------
      -- node alloc
      -- ----------------------        
      WHEN nalloc_start =>
        nstate <= nalloc_wait;
      WHEN nalloc_wait =>
        nstate <= nalloc_wait;
        IF alloc_in.done = '1' THEN
          nstate <= nalloc_done;
        END IF;
      WHEN nalloc_done =>
        nstate <= wnode_start;


      -- -----------------------
      -- update prev node
      -- ----------------------  
      WHEN pupdate =>
        nstate <= wnode_start;
      -- -----------------------
      -- deletion
      -- ----------------------               
      WHEN deletion =>
      -- -----------------------
      -- balancing
      -- ----------------------
      WHEN balance_start =>
      WHEN balance_wait =>
      WHEN balance_done =>

      -- -----------------------
      -- done state
      -- ----------------------
      WHEN isdone =>
      WHEN OTHERS => nstate <= idle;
    END CASE;


  END PROCESS;

  ild_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state          <= nstate;
    done           <= '0';
    alloc_in.start <= '0';
    node_request   <= '0';
    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          rootPtr            <= rootPtr_IN;
          flag_creating_root <= '0';
          flag_new_node      <= '0';
          flag_pupdating     <= '0';
          flag_left_create   <= '0';
          
        WHEN root_check =>
          IF rootPtr = nullPtr THEN
            flag_creating_root <= '1';
          END IF;
        WHEN isdone =>
          done        <= '1';
          rootPtr_OUT <= rootPtr;
        -- -----------------------
        -- read node
        -- -----------------------     
        WHEN rnode_start =>
          node_request.cmd   <= rnode;
          node_request.start <= '1';
        WHEN rnode_done =>
        -- stuff
        -- -----------------------
        -- write node
        -- -----------------------  
        WHEN wnode_start =>
          node_request.cmd   <= wnode;
          node_request.start <= '1';
          
        WHEN wnode_done =>
        -- stuff
        -- -----------------------
        -- node alloc
        -- ----------------------        
        WHEN nalloc_start =>
          alloc_in.start   <= '1';
          nodeNew.key      <= key;
          nodeNew.data     <= data;
          nodeNew.height   <= 1;
          nodeNew.leftPtr  <= nullPtr;
          nodeNew.rightPtr <= nullPtr;
          flag_new_node    <= '1';
          IF flag_creating_root = '0' THEN
            nodeParent <= nodeIn;
          END IF;
        WHEN nalloc_done =>
          nodeNew.ptr                <= alloc_in.ptr;
          node_request.ptr           <= alloc_in.ptr;    -- stuff
          node_request.node.ptr      <= alloc_in.ptr;
          node_request.node.key      <= nodeNew.key;
          node_request.node.data     <= nodeNew.data;
          node_request.node.height   <= nodeNew.height;
          node_request.node.leftPtr  <= nodeNew.leftPtr;
          node_request.node.rightPtr <= nodeNew.rightPtr;
          IF flag_creating_root = '1' THEN
            rootPtr <= alloc_in.ptr;
          END IF;
          IF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
            flag_left_create <= '1';
          END IF;
        -- -----------------------
        -- update parent node after node alloc
        -- ----------------------
        WHEN pupdate =>
          flag_new_node              <= '0';
          flag_pupdating             <= '1';
          node_request.ptr           <= nodeParent.ptr;  -- stuff
          node_request.node.ptr      <= nodeParent.ptr;
          node_request.node.key      <= nodeParent.key;
          node_request.node.data     <= nodeParent.data;
          node_request.node.height   <= nodeParent.height;
          node_request.node.leftPtr  <= nodeParent.leftPtr;
          node_request.node.rightPtr <= nodeParent.rightPtr;
          IF flag_left_create = '1' THEN
            node_request.node.leftPtr <= nodeNew.ptr;
          ELSE
            node_request.rightPtr <= nodeNew.ptr;
          END IF;
        WHEN OTHERS => NULL;
      END CASE;

    END IF;  -- if reset

  END PROCESS;
  
END ARCHITECTURE;



