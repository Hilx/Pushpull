LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE config_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  CONSTANT CONST_RESET : STD_LOGIC := '1';  -- active high 1, active low 0

  CONSTANT nullPtr : slv(31 DOWNTO 0) := x"FFFF0000";

  -- CONFIGURATION CONSTANTS -- pay attention to moving simulation to synthrun
  CONSTANT MEM_BASE          : slv(31 DOWNTO 0) := x"00000000";
  CONSTANT MEM_BLOCK_SIZE    : slv(31 DOWNTO 0) := x"00000011";  -- 24B(3 words)
  CONSTANT LIST_LENGTH       : INTEGER          := 496;  -- total mem = 16384*16B
  CONSTANT ADDR_WORD_OFF_BIN : INTEGER          := 0;  --0 for bram, 2 for ddr
  CONSTANT ADDR_WORD_OFF_DEC : UNSIGNED         := x"00000001";  -- 1 for bram, 4 for ddr

  -- HASH TABLE
  -- LINKED LIST USED
  -- OFFSETS
  CONSTANT KEY_OFFSET  : UNSIGNED := x"00000001";  -- 1 for bram, 4 for ddr
  CONSTANT DATA_OFFSET : UNSIGNED := x"00000010";  -- 2 for bram, 8 for ddr

  -- hashing
  CONSTANT HASH_MASKING     : INTEGER := 3;
  CONSTANT TOTAL_HASH_ENTRY : INTEGER := 8;  -- 65536;  -- (2^16)

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

  -- TOP LEVEL COMMAND CONSTANTS
  CONSTANT MALLOC_INIT : slv(2 DOWNTO 0) := x"0";
  CONSTANT HASH_INIT   : slv(2 DOWNTO 0) := x"1";
  CONSTANT INS_ITEM    : slv(2 DOWNTO 0) := x"4";
  CONSTANT DEL_ITEM    : slv(2 DOWNTO 0) := x"5";
  CONSTANT SER_ITEM    : slv(2 DOWNTO 0) := x"6";
  CONSTANT ALL_DELETE : slv(2 DOWNTO 0) := x"7";

END PACKAGE;
