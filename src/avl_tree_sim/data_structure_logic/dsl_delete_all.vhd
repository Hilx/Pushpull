LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;
USE work.dsl_pack_func.ALL;

ENTITY dsl_delete_all IS
  PORT(
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;
    start         : IN  STD_LOGIC;
    done          : OUT STD_LOGIC;
    rootPtr_IN    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- allocator
    alloc_in      : IN  allocator_com_type;
    alloc_out     : OUT allocator_com_type;
    -- node access
    node_request  : OUT node_access_comm_type;
    node_response : IN  node_access_comm_type
    );
END ENTITY dsl_delete_all;

ARCHITECTURE syn_da OF dsl_delete_all IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate   : delete_all_state_type;
  SIGNAL nodeIn          : tree_node_type;
  SIGNAL mystack         : stack_type;
  SIGNAL nowPtr, freePtr : slv(31 DOWNTO 0);
  SIGNAL saddr           : INTEGER;
  SIGNAL key_freed       : slv(31 DOWNTO 0);

BEGIN
  da_comb : PROCESS(state, start, alloc_in, node_response, saddr, rootPtr_IN, nodeIn)
  BEGIN
    nstate <= idle;                     -- default
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF start = '1' THEN
                     nstate <= checkroot;
                   END IF;
      WHEN checkroot => nstate <= rnode_start;
                        IF rootPtr_IN = nullPtr
                          -- AND flag_stack_empty = '1' THEN
                          AND saddr = 0 THEN
                          nstate <= isdone;
                        END IF;
      -- ------------------------------
      -- ---------- READ NODE ---------
      -- ------------------------------
      WHEN rnode_start => nstate <= rnode_wait;
      WHEN rnode_wait  => nstate <= rnode_wait;
                          IF node_response.done = '1' THEN
                            nstate <= rnode_done;
                          END IF;
      WHEN rnode_done => nstate <= check_node;
      -- ------------------------------
      -- ---------- FREE --------------
      -- ------------------------------
      WHEN free_start => nstate <= free_wait;
      WHEN free_wait  => nstate <= free_wait;
                         IF alloc_in.done = '1' THEN
                           nstate <= free_done;
                         END IF;
      WHEN free_done => nstate <= read_stack;
                        -- IF flag_stack_empty = '1' THEN
                        IF saddr = 0 THEN
                          nstate <= isdone;
                        END IF;
      -- ------------------------------
      -- ---------- check node --------
      -- ------------------------------
      WHEN check_node => nstate <= write_stack;
                         IF nodeIn.leftPtr = nullPtr
                           AND nodeIn.rightPtr = nullPtr THEN
                           nstate <= free_start;
                         END IF;
      -- ------------------------------
      -- ---------- stacking ----------
      -- ------------------------------
      WHEN read_stack  => nstate <= update_node;
      WHEN update_node => nstate <= check_node;
      WHEN write_stack => nstate <= rnode_start;
      -- ------------------------------
      -- ------------------------------
      -- ------------------------------
      WHEN isdone      => nstate <= idle;
      WHEN OTHERS      => nstate <= idle;
    END CASE;
  END PROCESS;

  da_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state              <= nstate;
    alloc_out.start    <= '0';
    node_request.start <= '0';
    done               <= '0';
    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          saddr <= 0;
        WHEN checkroot =>
          nowPtr <= rootPtr_IN;
        -- ------------------------------
        -- ---------- READ NODE ---------
        -- ------------------------------
        WHEN rnode_start =>
          node_request.start <= '1';
          node_request.ptr   <= nowPtr;
          node_request.cmd   <= rnode;
        WHEN rnode_done =>
          nodeIn <= node_response.node;
        -- ------------------------------
        -- ---------- FREE --------------
        -- ------------------------------
        WHEN free_start =>
          alloc_out.start <= '1';
          alloc_out.ptr   <= freePtr;
        -- ------------------------------
        -- ---------- check node --------
        -- ------------------------------
        WHEN check_node =>
          IF nodeIn.leftPtr = nullPtr
            AND nodeIn.rightPtr = nullPtr THEN
            freePtr   <= nodeIn.ptr;
            key_freed <= nodeIn.key;
          END IF;
        -- ------------------------------
        -- ---------- stacking ----------
        -- ------------------------------
        WHEN read_stack =>
          nodeIn <= mystack(saddr - 1);
          saddr  <= saddr - 1;
        WHEN update_node =>
          IF to_integer(uns(key_freed)) < to_integer(uns(nodeIn.key)) THEN
            nodeIn.leftPtr <= nullPtr;
          ELSIF to_integer(uns(key_freed)) > to_integer(uns(nodeIn.key)) THEN
            nodeIn.rightPtr <= nullPtr;
          END IF;
        WHEN write_stack =>
          mystack(saddr) <= nodeIn;
          saddr          <= saddr + 1;
          IF nodeIn.leftPtr /= nullPtr THEN
            nowPtr <= nodeIn.leftPtr;
          ELSIF nodeIn.rightPtr /= nullPtr THEN
            nowPtr <= nodeIn.rightPtr;
          END IF;
        -- ------------------------------
        -- ------------------------------
        -- ------------------------------
        WHEN isdone => done <= '1';
        WHEN OTHERS => NULL;
      END CASE;

    END IF;  -- reset stuff
    
  END PROCESS;

  alloc_out.cmd <= free;

END ARCHITECTURE;
