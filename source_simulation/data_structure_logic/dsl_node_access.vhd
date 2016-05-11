-- 10 May 2016: developed for accessing one node word by word
-- later will be modified into bursting read/write whole node
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE dsl_pack.ALL;

ENTITY dsl_node_access IS
  PORT(
    clk      : IN  STD_LOGIC;
    rst      : IN  STD_LOGIC;
    request  : IN  node_access_comm_type;
    response : OUT node_access_comm_type;
    mcin     : IN  mem_control_type;
    mcout    : OUT mem_control_type
    )
END ENTITY;

ARCHITECTURE syn_dsl_node_access OF dsl_node_access IS
  SIGNAL state, nstate : node_access_state_type;
BEGIN
  na_comb : PROCESS(request, mcin, state)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF request.start = '1' THEN
                     nstate <= r0start;
                     IF request.cmd = nwrite THEN
                       nstate <= w0start;
                     END IF;
                   END IF;
      WHEN r0start => nstate <= r0wait;
      WHEN r0wait  => nstate <= r0wait;
                      IF mcin.done = '1' THEN
                        nstate <= r1start;
                      END IF;
      WHEN r1start => nstate <= r1wait;
      WHEN r1wait  => nstate <= r1wait;
                      IF mcin.done = '1' THEN
                        nstate <= r2start;
                      END IF;
      WHEN r2start => nstate <= r2wait;
      WHEN r2wait  => nstate <= r2wait;
                      IF mcin.done = '1' THEN
                        nstate <= done;
                      END IF;
      WHEN w0start => nstate <= w0wait;
      WHEN w0wait  => nstate <= w0wait;
                      IF mcin.done = '1' THEN
                        nstate <= w1start;
                      END IF;
      WHEN w1start => nstate <= w1wait;
      WHEN w1wait  => nstate <= w1wait;
                      IF mcin.done = '1' THEN
                        nstate <= w2start;
                      END IF;
      WHEN w2start => nstate <= w2wait;
      WHEN w2wait  => nstate <= w2wait;
                      IF mcin.done = '1' THEN
                        nstate <= done;
                      END IF;
      WHEN done   => nstate <= idle;
      WHEN OTHERS => nstate <= idle;
    END CASE;
  END PROCESS;

  na_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    state         <= nstate;
    response.done <= '0';
    mcout.start   <= '0';

    IF rst = CONST_RESET THEN
      state <= idle;
    ELSE
      CASE state IS
        -- read node
        WHEN r0start => mcout.cmd <= mread;
                        mcout.start <= '1';
        WHEN r1start => mcout.start <= '1';
                        response.node.ptr     <= request.ptr;
                        response.node.nextPtr <= mcin.rdata;
        WHEN r2start => mcout.start <= '1';
                        response.node.key <= mcin.rdata;

        -- write node
        WHEN w1start => mcout.cmd <= mwrite;
                        mcout.start <= '1';
                        mcout.addr  <= request.ptr;
                        mcout.wdata <= request.node.nextPtr;
        WHEN w2start => mcout.start <= '1';
                        mcout.addr  <= slv(UNSIGNED(request.ptr) + KEY_OFFSET);
                        mcout.wdata <= request.node.key;
        WHEN w3start => mcout.start <= '1';
                        mcout.addr  <= slv(UNSIGNED(request.ptr)+ DATA_OFFSET);
                        mcout.wdata <= request.node.data;

        -- done 
        WHEN done => response.done <= '1';
                     IF request.cmd = nread THEN
                       response.node.data <= mcin.rdata;
                     END IF;
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- about reset
    
  END PROCESS;

END ARCHITECTURE;
