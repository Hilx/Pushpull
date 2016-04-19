library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.malloc_pack.all;               -- memory management package

entity mmu is  -- memory management unit a.k.a memory allocator
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    arg      : in  allocator_com_type;
    ret      : out allocator_com_type;
    mcin     : in  mem_control_type;
    mcout    : out mem_control_type;
    mmu_init : in  mmu_init_type
    );
end entity mmu;

architecture syn_mmu of mmu is

  signal hdList                : slv(31 downto 0);
  signal mmu_state, mmu_nstate : allocator_state_type;
begin
  mmu_fsm_comb : process(mmu_state, arg, mcin, mmu_init)
  begin
    case mmu_state is
      when mmu_state_idle =>
        mmu_nstate <= mmu_state_idle;   -- default next state
        if mmu_init.start = '1' then
          mmu_nstate <= mmu_state_init;
        end if;
        if arg.start = '1' then         -- if there is a new request
          mmu_nstate <= mmu_state_malloc;    -- if malloc
          if arg.cmd = free then        -- if free
            mmu_nstate <= mmu_state_free;
          end if;
        end if;
      when mmu_state_malloc =>
        mmu_nstate <= mmu_state_read_wait;
      when mmu_state_read_wait =>
        mmu_nstate <= mmu_state_read_wait;   -- stay in state by default
        if mcin.done = '1' then         -- if read finished, go to done state
          mmu_nstate <= mmu_state_done;
        end if;
      when mmu_state_free =>
        mmu_nstate <= mmu_state_write_wait;
      when mmu_state_write_wait =>
        mmu_nstate <= mmu_state_write_wait;  -- stay in state by default
        if mcin.done = '1' then         -- if write finished, go to done state
          mmu_nstate <= mmu_state_done;
        end if;
      when mmu_state_done =>
        mmu_nstate <= mmu_state_idle;
      when mmu_state_init =>
        mmu_nstate <= mmu_state_init_wait;
      when mmu_state_init_wait =>
        mmu_nstate <= mmu_state_init_wait;
        if mmu_init.done = '1' then
          mmu_nstate <= mmu_state_idle;
        end if;
      when others =>
        mmu_nstate <= mmu_state_idle;   -- to avoid latches
    end case;
  end process mmu_fsm_comb;

  mmu_fsm_reg : process
  begin
    wait until clk'event and clk = '1';
    -- update state
    mmu_state   <= mmu_nstate;
    -- default control signal values
    mcout.start <= '0';
    ret.done    <= '0';

    if rst = CONST_RESET then
      mmu_state <= mmu_state_idle;
    else
      case mmu_state is
        when mmu_state_malloc =>        -- in state malloc
          ret.ptr     <= hdList;   -- return the hdList as allocated pointer
          -- to update list of mem blocks
          mcout.start <= '1';
          mcout.cmd   <= mc_read;
          mcout.addr  <= hdList;
        when mmu_state_free =>          -- in state free
          -- to update list of mem blocks
          mcout.start <= '1';
          mcout.cmd   <= mc_write;
          mcout.addr  <= arg.ptr;       -- write in header of freed mem block
          mcout.data  <= hdList;        -- the old hdList
        when mmu_state_done =>          -- in state done
          ret.done <= '1';
          -- update hdList
          hdList   <= mcin.data;         -- if malloc
          if arg.cmd = free then
            hdList <= arg.ptr;
          end if;
        when mmu_state_init =>          -- assign initial hdList address
          hdList <= MEM_BASE;
        when others => null;
      end case;
    end if;  -- reset or not
  end process mmu_fsm_reg;

end architecture syn_mmu;
