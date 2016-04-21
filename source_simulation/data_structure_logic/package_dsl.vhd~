LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE dsl_pack IS
  ALIAS slv IS STD_LOGIC_VECTOR;

  TYPE dsl_cmd_type IS(insert, delete, lookup);

  TYPE dsl_com_in_type IS RECORD
    key   : slv(31 DOWNTO 0);
    data  : slv(31 DOWNTO 0);
    cmd   : dsl_cmd_type;
    start : STD_LOGIC;
  END RECORD;

  TYPE dsl_com_out_type IS RECORD
    data : slv(31 DOWNTO 0);
    done : STD_LOGIC;
  END RECORD;

END PACKAGE;
