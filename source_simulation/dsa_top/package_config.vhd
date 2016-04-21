LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE config_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  CONSTANT CONST_RESET : STD_LOGIC := '1';  -- active high 1, active low 0

  -- CONFIGURATION CONSTANTS
  CONSTANT MEM_BASE       : slv(31 DOWNTO 0) := x"10000000";
  CONSTANT MEM_BLOCK_SIZE : slv(31 DOWNTO 0) := x"00000010";  -- 16B
  CONSTANT LIST_LENGTH    : INTEGER          := 16384;  -- total mem = 16384*16B

  -- memory controller related signals

  TYPE mem_cmd_type IS (mwrite, mread);

  TYPE mem_control_type IS RECORD
    start : STD_LOGIC;
    done  : STD_LOGIC;
    cmd   : mem_cmd_type;
    addr  : slv(31 DOWNTO 0);
    wdata : slv(31 DOWNTO 0);
    rdata : slv(31 DOWNTO 0);
  END RECORD;

END PACKAGE;