LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;          -- write to files 
USE work.ALL;
USE work.config_pack.ALL;
USE work.dsa_top_pack.ALL;
USE work.dsl_pack.ALL;
USE work.tb_pack_v1.ALL;                -- malloc-only testing tb package

ENTITY tb_v0 IS
END ENTITY tb_v0;

ARCHITECTURE behav_tb_v0 OF tb_v0 IS
  -- write to file
  FILE fout                  : TEXT OPEN write_mode IS "TEST_RESULT.txt";
  -- --------
  ALIAS slv IS STD_LOGIC_VECTOR;
  -- system signals
  SIGNAL clk                 : STD_LOGIC;
  SIGNAL rst                 : STD_LOGIC;
  -- port mapping dsa
  SIGNAL myPtr               : slv(31 DOWNTO 0);  -- pointer allocated returned
  SIGNAL dsa_req             : dsa_request_type;  -- test input send to dsa
  SIGNAL DSA_RETURN_DATA     : slv(31 DOWNTO 0);
  SIGNAL DSA_DONE_BIT        : STD_LOGIC;
  SIGNAL m_request           : mem_control_type;  -- memory control from dsa
  SIGNAL m_response          : mem_control_type;  -- memory control to dsa
  -- memory signals
  SIGNAL ram_we              : STD_LOGIC;         -- write enable
  SIGNAL ram_addr            : slv(31 DOWNTO 0);
  SIGNAL ram_wdata           : slv(31 DOWNTO 0);
  SIGNAL ram_rdata           : slv(31 DOWNTO 0);
  SIGNAL ram_done_i          : STD_LOGIC;
  -- tb fsm signals
  SIGNAL tb_state, tb_nstate : tb_fsm_v0_type;
  -- for extracting inputs from package
  SIGNAL test_index          : INTEGER;
  -- faking memory controller done signal
  SIGNAL fake_it             : INTEGER;
BEGIN
  -- -------------------------------------
  -- ----- Connections and Port Maps -----
  -- -------------------------------------
  dsa0 : ENTITY dsa_top_wrapper
    PORT MAP(
      PTR_OUT      => myPtr,
      clk          => clk,
      rst          => rst,
      -- dsl communication
      request      => dsa_req,
      dsl_data_out => DSA_RETURN_DATA,
      DSA_DONE_BIT => DSA_DONE_BIT,
      -- memory controller communciation
      tmc_in       => m_request,
      tmc_out      => m_response
      );
  ram0 : ENTITY block_ram
    PORT MAP(
      clk      => clk,
      we       => ram_we,
      address  => ram_addr,
      data_in  => ram_wdata,
      data_out => ram_rdata
      );

  -- -------------------------------------
  -- Memory Interaction ------------------
  -- -------------------------------------
  -- things go into memory
  ram_addr  <= m_request.addr;
  ram_wdata <= m_request.wdata;
  memcmd : PROCESS(m_request)
  BEGIN
    ram_we <= '0';
    IF m_request.cmd = mwrite THEN
      ram_we <= m_request.start;
    END IF;
  END PROCESS;
  -- things come out of memory
  m_response.rdata <= ram_rdata;
  m_response.done  <= ram_done_i;
  -- we also need a done for m_response.done
  -- let's fake one!
  memdone : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    ram_done_i <= '0';                  -- done bit is usually 0
    fake_it    <= 0;
    IF ram_we = '1' THEN
      fake_it <= 1;
    END IF;
    IF fake_it = 1 THEN
      fake_it <= 2;
    END IF;
    IF fake_it = 2 THEN
      fake_it <= 3;
    END IF;
    IF fake_it = 3 THEN
      ram_done_i <= '1';                -- after waiting, done bit becomes 1
    END IF;
  END PROCESS;

  -- -------------------------------------
  -- ---------- Clock Generation ---------
  -- ------------------------------------- use std.textio.all; 
  p1_clkgen : PROCESS
  BEGIN
    clk <= '0';
    WAIT FOR 50 ns;
    clk <= '1';
    WAIT FOR 50 ns;
  END PROCESS p1_clkgen;

  -- -------------------------------------
  -- TB FSM: init and send commands ------
  -- -------------------------------------
  tb_fsm0_comb : PROCESS(tb_state, DSA_DONE_BIT,test_index)
  BEGIN
    tb_nstate <= idle;
    CASE tb_state IS
      WHEN idle    => tb_nstate <= ready;
      WHEN ready   => tb_nstate <= command;
      WHEN command => tb_nstate <= busy;
      WHEN busy    => tb_nstate <= busy;
                      IF DSA_DONE_BIT = '1' THEN
                        tb_nstate <= check;
                      END IF;
      WHEN check => tb_nstate <= ready;
                    IF myTest(test_index).last = '1' THEN
                      tb_nstate <= isdone;
                    END IF;
      WHEN isdone =>
        ASSERT false REPORT "TEST FINISHED*>__<*!" SEVERITY failure;  -- stop tb
    END CASE;
  END PROCESS;

  tb_fsm0_reg : PROCESS
    -- write to file variables
    VARIABLE outline : LINE;
    VARIABLE out_int : slv(31 downto 0);
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

    tb_state      <= tb_nstate;
    dsa_req.start <= '0';
    IF rst = CONST_RESET THEN
      tb_state <= idle;
    ELSE
      CASE tb_state IS
        WHEN idle => test_index <= 0;
        WHEN command =>
          dsa_req.cmd   <= myTest(test_index).cmd;
          dsa_req.key   <= myTest(test_index).key;
          dsa_req.data  <= myTest(test_index).data;
          dsa_req.start <= '1';
          -- update text extracting info
          test_index    <= test_index + 1;
        WHEN check =>
          -- write to file
          write(outline, (test_index-1));
          out_int := DSA_RETURN_DATA;
          write(outline, out_int);
          writeline(fout, outline);
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- if reset stuff    
  END PROCESS;

END ARCHITECTURE behav_tb_v0;
