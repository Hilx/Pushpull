LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsa_top_pack IS
  ALIAS slv IS standard_logic_vector;

  TYPE dsa_top_mem_comd_type IS (mwrite, mread);

  TYPE dsa_top_mem_control_type IS RECORD
    cmd        : dsa_top_mem_cmd_type;  -- for ddr
    write_data : slv(31 DOWNTO 0);
    read_data  : slv(31 DOWNTO 0);
    addr       : slv(31 DOWNTO 0);
    start      : STD_LOGIC;             -- write enable/for ddr
    done       : STD_LOGIC;
  END RECORD;

END PACKAGE;
