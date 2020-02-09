----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: CountGensOn - Behavioral
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

entity CountGensOn is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		
		notesOnOff		:	in	std_logic_vector(15 downto 0);		
		numGensOn		:	out std_logic_vector(4 downto 0)
		
  );
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  CountGensOn  :   entity  is  "true";
end CountGensOn;

use work.my_common.all;

architecture Behavioral of CountGensOn is

begin

  
process(rst_n,clk,notesOnOff)
	type sum_t 	is array ( 0 to 15 ) of unsigned(4 downto 0);

	variable sum	:	sum_t;

begin
    sum(0) := to_unsigned(0,5);
    if notesOnOff(0)='1' then
        sum(0) := to_unsigned(1,5);
    end if;
	
    if rst_n='0' then
		numGensOn <=(others=>'0');
        
	elsif rising_edge(clk) then
        -- Pipelined sum
        for i in 1 to 15 loop
            sum(i) := sum(i-1);
            if notesOnOff(i)='1' then
                sum(i) := sum(i-1)+to_unsigned(1,5);
            end if;
        end loop;
		
		numGensOn <= std_logic_vector(sum(15));
	   
    end if;
end process;
  
end Behavioral;
