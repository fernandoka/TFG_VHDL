----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ChromaticScale - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.1
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ChromaticScale is
  Generic(
        NUM_NOTES   :   natural;
		TEMP_VALUE	:	natural
  );
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen             :   in  std_logic;
		numNote			:	out std_logic_vector(15 downto 0);
        notes_on		:	out	std_logic_vector(NUM_NOTES-1 downto 0)
  );
-- Attributes for debug
attribute   dont_touch    :   string;
attribute   dont_touch  of  ChromaticScale  :   entity  is  "true";
    
end ChromaticScale;

use work.my_common.all;

architecture Behavioral of ChromaticScale is

begin

fsmt:
process(rst_n,clk)
    type states is ( idle, start, shiftLeft,shiftRight);	
	type fsmt_state is record
        state   :   states;
        temp   	:   natural range 0 to TEMP_VALUE;
	end record;
	variable state	:	fsmt_state;
	variable cntr	:	natural range 0 to NUM_NOTES-1;
	variable reg    :   std_logic_vector(NUM_NOTES-1 downto 0);
begin
    
	numNote <= std_logic_vector(to_unsigned(cntr,16));
	notes_on <= reg;
	
    if rst_n='0' then
        reg := (others=>'0');		
        cntr :=0;
		state := (idle,0);
		
    elsif rising_edge(clk) then
		if state.temp/=0 then
			state.temp := state.temp-1;
		else
			case state.state is
				when idle=>
					if cen='1' then
						cntr :=0;
						reg :=(others=>'0');
						state.state := start;
					end if;
				
				when start =>
					reg(NUM_NOTES-1 downto 1) :=(others=>'0');
					reg(0) :='1';
					state := (shiftLeft,TEMP_VALUE);
				
				when shiftLeft =>
					if cntr/=NUM_NOTES-1 then
                        reg := reg(NUM_NOTES-2 downto 0) & '0';
						cntr := cntr+1;
						state.temp := TEMP_VALUE;
					else
						cntr := 0;
						state :=(shiftRight,TEMP_VALUE);
					end if;

				when shiftRight =>
					reg := '0' & reg(NUM_NOTES-1 downto 1);
					if cntr/=NUM_NOTES-1 then
						cntr := cntr+1;
						state.temp :=TEMP_VALUE;
					else
						state :=(idle,0);
					end if;
				
			end case;
		end if; -- if state.temp/=0	
        
    end if;
end process;
  
end Behavioral;
