LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_lookup IS
  PORT(
    clk                : IN  STD_LOGIC;
    rst                : IN  STD_LOGIC;
    rootPtr_IN         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    lookup_larger      : IN  STD_LOGIC;
    -- control
    start              : IN  STD_LOGIC;
    done               : OUT STD_LOGIC;
    key                : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    lookup_result      : OUT dsl_lookup_result_type;
    -- node access
    node_request_port  : OUT node_access_comm_type;
    node_response_port : IN  node_access_comm_type
    );
END ENTITY dsl_lookup;

ARCHITECTURE dsl_lookup_syn OF dsl_lookup IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate : lookup_state_type;
  SIGNAL nodeIn, nodeS : tree_node_type;
  SIGNAL nowPtr        : slv(31 DOWNTO 0);
  SIGNAL saddr         : INTEGER;
  SIGNAL mystack       : stack_type;
BEGIN
  lookup_comb : PROCESS(state, start, key, nodeIn, node_response_port,
                        rootPtr_IN, nodeS, saddr, lookup_larger)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF start = '1' THEN
                     nstate <= checkroot;
                   END IF;
      WHEN checkroot => nstate <= rnode_start;
                        IF rootPtr_IN = nullPtr THEN
                          nstate <= isdone;
                        END IF;
      WHEN rnode_start => nstate <= rnode_wait;
      WHEN rnode_wait  => nstate <= rnode_wait;
                          IF node_response_port.done = '1' THEN
                            nstate <= rnode_done;
                          END IF;
      WHEN rnode_done => nstate <= comparekey;
      WHEN comparekey =>
        nstate <= rnode_start;
        IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
          nstate <= isdone;             -- search done
        ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.leftPtr = nullPtr THEN
            nstate <= isdone;           -- search ended, not found
          END IF;
        ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
          IF nodeIn.rightPtr = nullPtr THEN
            nstate <= isdone;           -- search ended, not found
          END IF;
        END IF;
        IF lookup_larger = '1' THEN
          nstate <= write_stack;
          IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
            nstate <= read_extra_node;  -- find smallest in right sub tree
            IF nodeIn.rightPtr = nullPtr THEN
              nstate <= read_stack;
            END IF;
          ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
            -- by default, write stack, read next node
            IF nodeIn.leftPtr = nullPtr THEN
              nstate <= isdone;         -- and return nodeIn.data
            END IF;
          ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
            -- by default, write stack, read next node
            IF nodeIn.rightPtr = nullPtr THEN
              nstate <= read_stack;
            END IF;
          END IF;
        END IF;
      WHEN read_stack => nstate <= compare_stack;
      WHEN compare_stack =>
        nstate <= read_stack;
        IF to_integer(uns(key)) < to_integer(uns(nodeS.key)) OR saddr = 0 THEN
          nstate <= isdone;
        END IF;
      WHEN write_stack          => nstate <= rnode_start;
      WHEN read_extra_node      => nstate <= read_extra_node_wait;
      WHEN read_extra_node_wait => nstate <= read_extra_node_wait;
                                   IF node_response_port.done = '1' THEN
                                     nstate <= read_extra_node_done;
                                   END IF;
      WHEN read_extra_node_done => nstate <= read_extra_node;
                                   IF node_response_port.node.leftPtr = nullPtr THEN
                                     nstate <= isdone;
                                   END IF;
      WHEN isdone => nstate <= idle;
      WHEN OTHERS => nstate <= idle;
    END CASE;

  END PROCESS;

  lookup_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state                   <= nstate;
    node_request_port.start <= '0';
    done                    <= '0';

    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        WHEN idle =>
          nowPtr <= rootPtr_IN;
          saddr  <= 0;
        WHEN checkroot=>
          IF nowPtr = nullPtr THEN
            lookup_result.found <= '0';
          END IF;
        WHEN rnode_start =>
          node_request_port.start <= '1';
          node_request_port.cmd   <= rnode;
          node_request_port.ptr   <= nowPtr;
        WHEN rnode_done =>
          nodeIn <= node_response_port.node;
        WHEN comparekey =>
          IF lookup_larger = '0' THEN
            IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
              lookup_result.found <= '1';
              lookup_result.data  <= nodeIn.data;
            ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
              IF nodeIn.leftPtr = nullPtr THEN
                lookup_result.found <= '0';
              ELSE
                nowPtr <= nodeIn.leftPtr;
              END IF;
            ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
              IF nodeIn.rightPtr = nullPtr THEN
                lookup_result.found <= '0';
              ELSE
                nowPtr <= nodeIn.rightPtr;
              END IF;
            END IF;
          ELSE
            IF to_integer(uns(key)) = to_integer(uns(nodeIn.key)) THEN
              IF nodeIn.rightPtr /= nullPtr THEN
                nowPtr <= nodeIn.rightPtr;
              END IF;
            ELSIF to_integer(uns(key)) < to_integer(uns(nodeIn.key)) THEN
              IF nodeIn.leftPtr = nullPtr THEN
                lookup_result.found <= '1';
                lookup_result.data  <= nodeIn.key;
              ELSE
                nowPtr <= nodeIn.leftPtr;
              END IF;
            ELSIF to_integer(uns(key)) > to_integer(uns(nodeIn.key)) THEN
              IF nodeIn.rightPtr /= nullPtr THEN
                nowPtr <= nodeIn.rightPtr;
              END IF;
            END IF;
          END IF;
        WHEN write_stack =>
          myStack(saddr) <= nodeIn;
          saddr          <= saddr +1;
        WHEN read_stack =>
          nodeS <= myStack(saddr-1);
          saddr <= saddr -1;
        WHEN read_extra_node =>
          node_request_port.start <= '1';
          node_request_port.cmd   <= rnode;
          node_request_port.ptr   <= nowPtr;
        WHEN read_extra_node_done =>
          IF node_response_port.node.leftPtr = nullPtr THEN
            lookup_result.found <= '1';
            lookup_result.data  <= node_response_port.node.key;
          ELSE
            nowPtr <= node_response_port.node.leftPtr;
          END IF;
        WHEN compare_stack =>
          IF to_integer(uns(key)) < to_integer(uns(nodeS.key)) THEN
            lookup_result.found <= '1';
            lookup_result.data  <= nodeS.key;
          ELSE
            IF saddr = 0 THEN
              lookup_result.found <= '0';
            END IF;
          END IF;
        WHEN isdone => done <= '1';
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset
    
  END PROCESS;

END ARCHITECTURE;
