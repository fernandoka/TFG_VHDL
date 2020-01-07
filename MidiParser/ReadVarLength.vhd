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
-- Revision 0.2
-- Additional Comments:
--					 		
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ReadVarLength is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        readRqt			:	in	std_logic; -- One cycle high to request a read
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
		nextByte        :   in  std_logic_vector(7 downto 0);

		byteRqt			:	out std_logic; -- One cycle high to request a new byte
		dataRdy			:	out std_logic; -- One cycle high when the data is ready
		valOut			:	out	std_logic_vector(63 downto 0)
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ReadVarLength  :   entity  is  "true";
    
end ReadVarLength;
architecture Behavioral of ReadVarLength is

begin

fsm:
process(rst_n,clk,readRqt,byteAck)
    type states is (s0, s1);	
	variable state	:	states;
	variable regVal	:	std_logic_vector(63 downto 0);	
begin
    
	valOut <= regVal;
	
    if rst_n='0' then
		state := s0;
		byteRqt <='0';
		dataRdy <= '0';
		
    elsif rising_edge(clk) then
			byteRqt <='0';
			dataRdy <= '0';
			
			case state is
				when s0=>
					if readRqt='1' then
						regVal := (others=>'0');
						byteRqt <='1';
						state := s1;
					end if;
				
				when s1 =>
					if byteAck='1' then
						regVal := regVal(56 downto 0) & nextByte(6 downto 0);
						if nextByte(7)='1' then
							byteRqt <='1';
						else
							dataRdy <= '1';
							state := s0;
						end if;
					end if;

			end case;
    end if;
end process;
  
end Behavioral;
