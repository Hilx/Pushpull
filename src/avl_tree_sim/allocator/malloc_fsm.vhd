LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;               -- memory management package

ENTITY mmu IS  -- memory management unit a.k.a memory allocator
  PORT(
    clk                : IN  STD_LOGIC;
    rst                : IN  STD_LOGIC;
    total_entry_offset : IN  STD_LOGIC_VECTOR;
    argu               : IN  allocator_com_type;
    retu               : OUT allocator_com_type;
    mcin               : IN  mem_control_type;
    mcout              : OUT mem_control_type;
    mmu_init           : IN  mmu_init_type
    );
END ENTITY mmu;

ARCHITECTURE syn_mmu OF mmu IS
  ALIAS uns IS UNSIGNED;
  SIGNAL hdList                : slv(31 DOWNTO 0);
  SIGNAL mmu_state, mmu_nstate : allocator_state_type;
BEGIN
  
  mmu_fsm_comb : PROCESS(mmu_state, argu, mcin, mmu_init, hdList)
  BEGIN
    CASE mmu_state IS
      WHEN mmu_state_idle =>
        mmu_nstate <= mmu_state_idle;   -- default next state
        IF mmu_init.start = '1' THEN
          mmu_nstate <= mmu_state_init;
        END IF;
        IF argu.start = '1' THEN        -- if there is a new request
          mmu_nstate <= mmu_state_malloc;    -- if malloc
          IF hdList = nullPtr THEN      -- out of memory
            mmu_nstate <= mmu_state_done;
          END IF;
          IF argu.cmd = free THEN       -- if free
            mmu_nstate <= mmu_state_free;
          END IF;
        END IF;
      WHEN mmu_state_malloc =>
        mmu_nstate <= mmu_state_read_wait;
      WHEN mmu_state_read_wait =>
        mmu_nstate <= mmu_state_read_wait;   -- stay in state by default
        IF mcin.done = '1' THEN         -- if read finished, go to done state
          mmu_nstate <= mmu_state_done;
        END IF;
      WHEN mmu_state_free =>
        mmu_nstate <= mmu_state_write_wait;
      WHEN mmu_state_write_wait =>
        mmu_nstate <= mmu_state_write_wait;  -- stay in state by default
        IF mcin.done = '1' THEN         -- if write finished, go to done state
          mmu_nstate <= mmu_state_done;
        END IF;
      WHEN mmu_state_done =>
        mmu_nstate <= mmu_state_idle;
      WHEN mmu_state_init =>
        mmu_nstate <= mmu_state_init_wait;
      WHEN mmu_state_init_wait =>
        mmu_nstate <= mmu_state_init_wait;
        IF mmu_init.done = '1' THEN
          mmu_nstate <= mmu_state_idle;
        END IF;
      WHEN OTHERS =>
        mmu_nstate <= mmu_state_idle;   -- to avoid latches
    END CASE;
  END PROCESS mmu_fsm_comb;

  mmu_fsm_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    -- update state
    mmu_state   <= mmu_nstate;
    -- default control signal values
    mcout.start <= '0';
    retu.done   <= '0';

    IF rst = CONST_RESET THEN
      mmu_state <= mmu_state_idle;
    ELSE
      CASE mmu_state IS
        WHEN mmu_state_malloc =>        -- in state malloc
          retu.ptr    <= hdList;    -- retuurn the hdList as allocated pointer
          -- to update list of mem blocks
          mcout.start <= '1';
          mcout.cmd   <= mread;
          mcout.addr  <= hdList;
        WHEN mmu_state_free =>          -- in state free
          -- to update list of mem blocks
          mcout.start <= '1';
          mcout.cmd   <= mwrite;
          mcout.addr  <= argu.ptr;      -- write in header of freed mem block
          mcout.wdata <= hdList;        -- the old hdList
        WHEN mmu_state_done =>          -- in state done
          retu.done <= '1';
          -- update hdList
          hdList    <= mcin.rdata;      -- if malloc
          IF argu.cmd = free THEN
            hdList <= argu.ptr;
          END IF;
        WHEN mmu_state_init =>          -- assign initial hdList address
          hdList <= slv(uns(MEM_BASE));
        WHEN OTHERS => NULL;
      END CASE;
    END IF;  -- reset or not
  END PROCESS mmu_fsm_reg;

END ARCHITECTURE syn_mmu;
