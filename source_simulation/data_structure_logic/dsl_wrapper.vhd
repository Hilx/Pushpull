-- [2016-04-20] This code is currently part of the tb
-- for testing our dedicated malloc. 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;
USE work.dsl_pack.ALL;

ENTITY dsl_wrapper IS
  PORT(
    clk       : IN  STD_LOGIC;
    rst       : IN  STD_LOGIC;
    -- dsl communication
    dsl_in    : IN  dsl_com_in_type;
    dsl_out   : OUT dsl_com_out_type;
    -- allocator communication
    alloc_in  : IN  allocator_com_type;
    alloc_out : OUT allocator_com_type;
    -- memory controller communication
    mcin      : IN  mem_control_type;
    mcout     : OUT mem_control_type
    );
END ENTITY dsl_wrapper;

ARCHITECTURE syn_dsl_wrapper OF dsl_wrapper IS

  TYPE t_state_type IS (t_idle, t_start, t_wait, t_done);
  SIGNAL t_state, t_nstate : t_state_type;
  
BEGIN

  -- FOR TESTING MALLOC

  t_req_comb : PROCESS(dsl_in)
  BEGIN
    alloc_out.cmd <= malloc;
    IF dsl_in.cmd = delete THEN
      alloc_out.cmd <= free;
      alloc_out.ptr <= x"00000010";
    END IF;
  END PROCESS;

  t_fsm_comb : PROCESS(t_state, dsl_in, alloc_in)
  BEGIN
    t_nstate <= t_idle;
    CASE t_state IS
      WHEN t_idle =>
        t_nstate <= t_idle;
        IF dsl_in.start = '1' THEN
          t_nstate <= t_start;
        END IF;
      WHEN t_start=>
        t_nstate <= t_wait;
      WHEN t_wait =>
        t_nstate <= t_wait;
        IF alloc_in.done = '1' THEN
          t_nstate <= t_done;
        END IF;
      WHEN t_done =>
        t_nstate <= t_idle;
    END CASE;
  END PROCESS;

  t_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';

    t_state         <= t_nstate;
    alloc_out.start <= '0';
    dsl_out.done    <= '0';

    IF rst = CONST_RESET THEN
      t_state <= t_idle;
    ELSE
      IF t_state = t_start THEN
        alloc_out.start <= '1';
      END IF;
      IF t_state = t_done THEN
        dsl_out.done <= '1';
      END IF;
    END IF;

  END PROCESS;


END ARCHITECTURE syn_dsl_wrapper;
