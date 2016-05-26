-- 10 May 2016: developed for accessing one node word by word
-- later will be modified into bursting read/write whole node
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_node_access IS
  PORT(
    clk      : IN  STD_LOGIC;
    rst      : IN  STD_LOGIC;
    request  : IN  node_access_comm_type;
    response : OUT node_access_comm_type;
    mcin     : IN  mem_control_type;
    mcout    : OUT mem_control_type
    );
END ENTITY;

ARCHITECTURE syn_dsl_node_access OF dsl_node_access IS
  ALIAS uns IS UNSIGNED;
  SIGNAL state, nstate : node_access_state_type;
  SIGNAL out_i         : node_access_comm_type;
BEGIN
  na_comb : PROCESS(request, mcin, state)
  BEGIN
    nstate <= idle;
    CASE state IS
      WHEN idle => nstate <= idle;
                   IF request.start = '1' THEN
                     nstate <= r0start;
                     IF request.cmd = wnode THEN
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
                        nstate <= r3start;
                      END IF;
      WHEN r3start => nstate <= r3wait;
      WHEN r3wait  => nstate <= r3wait;
                      IF mcin.done = '1' THEN
                        nstate <= r4start;
                      END IF;
      WHEN r4start => nstate <= r4wait;
      WHEN r4wait  => nstate <= r4wait;
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
                        nstate <= w3start;
                      END IF;
      WHEN w3start => nstate <= w3wait;
      WHEN w3wait  => nstate <= w3wait;
                      IF mcin.done = '1' THEN
                        nstate <= w4start;
                      END IF;
      WHEN w4start => nstate <= w4wait;
      WHEN w4wait  => nstate <= w4wait;
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
        WHEN r0start => mcout.cmd <= mread;   -- starts reading left pointer
                        mcout.start <= '1';
                        mcout.addr  <= slv(uns(request.ptr) + LEFT_OFFSET);
        WHEN r1start => mcout.start <= '1';   -- starts reading right pointer
                        mcout.addr         <= slv(uns(request.ptr) + RIGHT_OFFSET);
                        out_i.node.ptr     <= request.ptr;
                        out_i.node.leftPtr <= mcin.rdata;
        WHEN r2start => mcout.start <= '1';   -- starts reading height
                        mcout.addr          <= slv(uns(request.ptr)+ HEIGHT_OFFSET);
                        out_i.node.rightPtr <= mcin.rdata;
        WHEN r3start => mcout.start <= '1';   -- starts reading key
                        mcout.addr        <= slv(uns(request.ptr) +KEY_OFFSET);
                        out_i.node.height <= to_integer(uns(mcin.rdata));
        WHEN r4start => mcout.start <= '1';   -- starts reading data;
                        mcout.addr     <= slv(uns(request.ptr)+DATA_OFFSET);
                        out_i.node.key <= mcin.rdata;
        -- write node
        WHEN w0start => mcout.cmd <= mwrite;  -- starts writing left pointer
                        mcout.start <= '1';
                        mcout.addr  <= slv(uns(request.ptr) + LEFT_OFFSET);
                        mcout.wdata <= request.node.leftPtr;
                        
        WHEN w1start => mcout.start <= '1';  -- starts writing right pointer
                        mcout.addr  <= slv(uns(request.ptr) + RIGHT_OFFSET);
                        mcout.wdata <= request.node.rightPtr;
        WHEN w2start => mcout.start <= '1';  -- starts writing height
                        mcout.addr  <= slv(uns(request.ptr) + HEIGHT_OFFSET);
                        mcout.wdata <= request.node.height;
        WHEN w3start => mcout.start <= '1';  -- starts writing key
                        mcout.addr  <= slv(uns(request.ptr) + KEY_OFFSET);
                        mcout.wdata <= request.node.key;
        WHEN w4start => mcout.start <= '1';  -- starts writing data
                        mcout.addr  <= slv(uns(request.ptr)+ DATA_OFFSET);
                        mcout.wdata <= request.node.data;
        -- done 
        WHEN done => response.done <= '1';
                     IF request.cmd = rnode THEN
                       response.node.data <= mcin.rdata;
                     END IF;
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- about reset
    
  END PROCESS;

  response <= out_i;

END ARCHITECTURE;
