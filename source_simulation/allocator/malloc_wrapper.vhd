LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.config_pack.ALL;
USE work.malloc_pack.ALL;               -- memory management package

ENTITY malloc_wrapper IS
  PORT(
    clk                : IN  STD_LOGIC;
    rst                : IN  STD_LOGIC;
    total_entry_offset : IN  STD_LOGIC_VECTOR;
    mmu_init_bit       : IN  STD_LOGIC;
    mmu_init_done      : OUT STD_LOGIC;
    -- Interval/DS communication
    argu               : IN  allocator_com_type;
    retu               : OUT allocator_com_type;
    -- External/Memory communication
    memcon_in          : IN  mem_control_type;
    memcon_out         : OUT mem_control_type
    );
END ENTITY;

ARCHITECTURE syn_malloc_wrapper OF malloc_wrapper IS
  -- wires/inter-connecting signals
  SIGNAL mmu_init    : mmu_init_type;
  SIGNAL mmu_mcin    : mem_control_type;
  SIGNAL mmu_mcout   : mem_control_type;
  SIGNAL init_input  : mem_control_type;
  SIGNAL init_output : mem_control_type;

  -- channel select FSM
  TYPE malloc_wrapper_state IS (mw_state_norm, mw_state_init);
  SIGNAL mw_state, mw_nstate : malloc_wrapper_state;
BEGIN
  -- wiring components
  mmu_init.start <= mmu_init_bit;

  mmu0 : ENTITY mmu
    PORT MAP(
      clk                => clk,
      rst                => rst,
      total_entry_offset => total_entry_offset,
      argu               => argu,
      retu               => retu,
      mcin               => mmu_mcin,
      mcout              => mmu_mcout,
      mmu_init           => mmu_init
      );

  mmu_init_done <= mmu_init.done;
  init0 : ENTITY mmu_init_block
    PORT MAP(
      clk                => clk,
      rst                => rst,
      total_entry_offset => total_entry_offsetm
      start              => mmu_init_bit,
      done               => mmu_init.done,
      mcin               => init_input,
      mcout              => init_output
      );

  -- channel select FSM
  mw_sel_comb : PROCESS(mw_state, mmu_init_bit, mmu_init)
  BEGIN
    mw_nstate <= mw_state_norm;
    CASE mw_state IS
      WHEN mw_state_norm =>
        -- fsm control
        mw_nstate <= mw_state_norm;
        IF mmu_init_bit = '1' THEN
          mw_nstate <= mw_state_init;
        END IF;
      WHEN mw_state_init =>
        mw_nstate <= mw_state_init;
        IF mmu_init.done = '1' THEN
          mw_nstate <= mw_state_norm;
        END IF;
    END CASE;

  END PROCESS;

  mw_sel_reg : PROCESS
  BEGIN
    WAIT UNTIL clk'event AND clk = '1';
    mw_state <= mw_nstate;
    IF rst = CONST_RESET THEN
      mw_state <= mw_state_norm;
    END IF;
  END PROCESS;

  mmu_mcin   <= memcon_in;
  init_input <= memcon_in;
  mw_sel_loggic : PROCESS(mw_state, mmu_mcout, init_output)
  BEGIN
    memcon_out <= mmu_mcout;
    IF mw_state = mw_state_init THEN
      memcon_out <= init_output;
    END IF;
  END PROCESS;
  
END ARCHITECTURE;
