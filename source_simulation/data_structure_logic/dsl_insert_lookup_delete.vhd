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
  SIGNAL ild_state, ild_nstate : dsl_ild_state_type;
  SIGNAL nodeIn                : hash_node_type;
  SIGNAL nodePrev              : hash_node_type;
  SIGNAL ptr_i, entryPtr       : slv(31 DOWNTO 0);
  SIGNAL flag_first            : STD_LOGIC;
BEGIN
  ild_fsm_comb : PROCESS(ild_state, start, cmd, mcin, alloc_in, node_response,
                         entryPtr, nodePrev,
                         key, nodeIn)
  BEGIN
    ild_nstate <= idle;                 -- default state
    CASE ild_state IS
      WHEN idle =>
        ild_nstate <= idle;
        IF start = '1' THEN
          ild_nstate <= hashing_start;
        END IF;
      -- --------------------
      -- HASHING
      WHEN hashing_start =>
        ild_nstate <= hashing_wait;
      WHEN hashing_wait =>
        ild_nstate <= hashing_wait;
        IF mcin.done = '1' THEN
          ild_nstate <= hashing_finish;
        END IF;
      WHEN hashing_finish =>
        ild_nstate <= rnode_start;
      -- --------------------
      -- READ NODE
      WHEN rnode_start =>
        ild_nstate <= rnode_wait;
      WHEN rnode_wait =>
        ild_nstate <= rnode_wait;
        IF mcin.done = '1' THEN
          ild_nstate <= rnode_valid;
        END IF;
      WHEN rnode_valid =>
        ild_nstate <= compare;
      -- --------------------
      -- COMPARISON
      WHEN compare =>
        ild_nstate <= rnode_start;      -- if smaller
        -- other cases
        IF cmd = lookup THEN
          IF key = nodeIn.key OR key > nodeIn.key OR nodeIn.nextPtr = nullPtr THEN
            ild_nstate <= isdone;
          END IF;
        ELSIF cmd = insert THEN
          IF key = nodeIn.key THEN
            ild_nstate <= isdone;
          ELSIF key > nodeIn.key OR nodeIn.nextPtr = nullPtr THEN
            ild_nstate <= insertion;
          END IF;
        ELSIF cmd = delete THEN
          IF key > nodeIn.key OR nodeIn.nextPtr = nullPtr THEN
            ild_nstate <= isdone;
          ELSIF key = nodeIn.key THEN
            ild_nstate <= deletion;
          END IF;
        END IF;
      -- --------------------
      WHEN isdone =>
        ild_nstate <= isdone;
      -- --------------------
      -- INSERTION
      WHEN insertion =>
        ild_nstate <= ins_alloc_wait;
      WHEN ins_alloc_wait =>
        ild_nstate <= ins_alloc_wait;
        IF alloc_in.done = '1' THEN
          ild_nstate <= ins_alloc_done;
        END IF;
      WHEN ins_alloc_done =>
        ild_nstate <= ins_wnode_wait;
      WHEN ins_wnode_wait =>
        ild_nstate <= ins_wnode_wait;
        IF node_response.done = '1' THEN
          ild_nstate <= ins_wnode_done;
        END IF;
      WHEN ins_wnode_done =>
        ild_nstate <= ins_nupdate_wait;
        IF entryPtr = nodePrev.ptr THEN
          ild_nstate <= ins_nentry_wait;
        END IF;
      WHEN ins_nupdate_wait =>
        ild_nstate <= ins_nupdate_wait;
        IF node_response.done = '1' THEN
          ild_nstate <= isdone;
        END IF;
      WHEN ins_nentry_wait =>
        ild_nstate <= ins_nentry_wait;
        IF mcin.done = '1' THEN
          ild_nstate <= isdone;
        END IF;
      -- --------------------
      -- DELETION
      WHEN deletion =>
        ild_nstate <= del_free_wait;
      WHEN del_free_wait =>
        ild_nstate <= del_free_wait;
        IF alloc_in.done = '1' THEN
          ild_nstate <= del_free_done;
        END IF;
      WHEN del_free_done =>
        ild_nstate <= del_nupdate_wait;
        IF entryPtr = nodePrev.ptr THEN
          ild_nstate <= del_nentry_wait;
        END IF;
      WHEN del_nupdate_wait =>
        ild_nstate <= del_nupdate_wait;
        IF node_response.done = '1' THEN
          ild_nstate <= isdone;
        END IF;
      WHEN del_nentry_wait =>
        ild_nstate <= del_nentry_wait;
        IF mcin.done = '1' THEN
          ild_nstate <= isdone;
        END IF;
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  ild_fsm_reg : PROCESS
    VARIABLE entry_index : UNSIGNED(31 DOWNTO 0);
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

    ild_state       <= ild_nstate;
    done            <= '0';
    alloc_out.start <= '0';
    mcout.start     <= '0';

    IF rst = CONST_RESET THEN
      ild_state <= idle;
    ELSE
      CASE ild_state IS
        WHEN hashing_start =>
          -- hashing
          entry_index(31 DOWNTO HASH_MASKING)  := (OTHERS => '0');
          entry_index(HASH_MASKING-1 DOWNTO 0) := UNSIGNED(key(HASH_MASKING-1 DOWNTO 0));
          mcout.addr                           <= slv(UNSIGNED(MEM_BASE) + (entry_index SLL ADDR_WORD_OFF_BIN));
          entryPtr                             <= slv(UNSIGNED(MEM_BASE) + (entry_index SLL ADDR_WORD_OFF_BIN));
          mcout.cmd                            <= mread;
          mcout.start                          <= '1';
          flag_first                           <= '1';
        WHEN hashing_finish =>
          ptr_i            <= mcin.rdata;
          node_request.ptr <= mcin.rdata;

          nodePrev.ptr     <= entryPtr;  -- indicating no prev node
          nodePrev.nextPtr <= mcin.rdata;
        WHEN isdone =>
          done <= '1';
          CASE cmd IS
            WHEN lookup =>
              lookup_result.data  <= nodeIn.data;
              lookup_result.found <= '0';
              IF key = nodeIn.key THEN
                lookup_result.found <= '1';
              END IF;
            WHEN insert =>
            WHEN delete =>
            WHEN OTHERS => NULL;
          END CASE;
        WHEN rnode_start =>
          node_request.cmd <= rnode;
        WHEN rnode_valid =>
          nodeIn.ptr     <= ptr_i;
          nodeIn.key     <= node_response.node.key;
          nodeIn.data    <= node_response.node.data;
          nodeIn.nextPtr <= node_response.node.nextPtr;
          IF flag_first = '0' THEN       -- update nodePrev
            nodePrev <= nodeIn;
          END IF;
        WHEN compare =>
          node_request.ptr <= nodeIn.nextPtr;
          ptr_i            <= nodeIn.nextPtr;
          flag_first       <= '0';
        -- -----------------------
        -- insertion
        WHEN insertion =>                -- node alloc
          alloc_out.cmd   <= malloc;
          alloc_out.start <= '1';
        WHEN ins_alloc_done =>
          node_request.start        <= '1';
          node_request.cmd          <= wnode;
          node_request.ptr          <= alloc_in.ptr;
          -- writing new node
          node_request.node.ptr     <= alloc_in.ptr;
          node_request.node.key     <= key;
          node_request.node.data    <= data;
          node_request.node.nextPtr <= nodeIn.ptr;
          -- update prev node nextPtr if isn't inserting
          -- to start of bucket
          IF nodePrev.ptr /= entryPtr THEN
            nodePrev.nextPtr <= alloc_in.ptr;
          END IF;
        WHEN ins_wnode_done =>
          IF nodePrev.ptr /= entryPtr THEN
            nodePrev <= nodeIn;
          ELSE
            mcout.cmd   <= mwrite;
            mcout.addr  <= entryPtr;
            mcout.wdata <= alloc_in.ptr;
            mcout.start <= '1';
          END IF;
        -- -----------------------
        -- deletion
        WHEN deletion =>
          alloc_out.cmd   <= free;
          alloc_out.start <= '1';
          alloc_out.ptr   <= nodeIn.ptr;
          -- update nodePrev nextPtr
          IF entryPtr /= nodePrev.ptr THEN
            nodePrev.nextPtr <= nodeIn.nextPtr;
          END IF;
        WHEN del_free_done =>
          IF entryPtr /= nodePrev.ptr THEN
            node_request.start <= '1';
            node_request.cmd   <= wnode;
            node_request.ptr   <= nodePrev.ptr;
            node_request.node  <= nodePrev;
          ELSE
            mcout.cmd   <= mwrite;
            mcout.addr  <= entryPtr;
            mcout.wdata <= nodeIn.nextPtr;
            mcout.start <= '1';
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset

  END PROCESS;

END ARCHITECTURE;



