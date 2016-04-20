LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.malloc_pack.ALL;               -- memory management package

ENTITY tb_malloc IS
END ENTITY tb_malloc;

ARCHITECTURE tb_malloc_behav OF tb_malloc IS
  -- memory

  -- signals for port mapping hwmalloc
  SIGNAL clk, rst, init_pulse            : STD_LOGIC;
  SIGNAL alloc_forw, alloc_back          : allocator_com_type;
  SIGNAL memcon_request, memcon_feedback : mem_control_type;
BEGIN
  -- port maps
  hwmalloc : ENTITY malloc_wrapper
    PORT MAP(
      clk          => clk,
      rst          => rst,
      mmu_init_bit => init_pulse,
      -- Interval/DS communication
      argu         => alloc_forw,
      retu         => alloc_back,
      -- External/Memory communication
      memcon_in    => memcon_request,
      memcon_out   => memcon_feedback
      );

  -- clockgen
  p1_clkgen : PROCESS
  BEGIN
    clk <= '0';
    WAIT FOR 50 ns;
    clk <= '1';
    WAIT FOR 50 ns;
  END PROCESS p1_clkgen;

END ARCHITECTURE tb_malloc_behav;
