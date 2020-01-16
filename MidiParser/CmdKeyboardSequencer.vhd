----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: CmdKeyboardSequencer - Behavioral
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
--		Command format: cmd(7 downto 0) = note code
--					 	cmd(9) = when high, note on	
--						cmd(8) = when high, note off
--						Null command when -> cmd(9 downto 0) = (others=>'0')
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

entity CmdKeyboardSequencer is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen				:	in	std_logic;
		
		-- Read Tracks Side
		cmdTrack_0		:	in	std_logic_vector(9 downto 0);
		cmdTrack_1		:	in	std_logic_vector(9 downto 0);
		seq_ack			:	out std_logic_vector(1 downto 0);
		
		--Keyboard side
		keyboard_ack	:	in	std_logic;
		cmdKeyboard		:	out std_logic_vector(9 downto 0)
		
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  CmdKeyboardSequencer  :   entity  is  "true";
    
end CmdKeyboardSequencer;
architecture Behavioral of CmdKeyboardSequencer is

begin

  
process(rst_n,clk,readRqt,byteAck)
	type states is (s0, s1, s2, s3);	
	variable state	:	states;
	
	variable regAux	:	std_logic_vector(9 downto 0);
	
begin
    
	cmdKeyboard <= regAux;
	
	regAux
    if rst_n='0' then
		turnFlag := '0';
		regAux := (others=>'0');
		seq_ack <=(others=>'0');
    
	elsif rising_edge(clk) then
		seq_ack <=(others=>'0');
				
		case state is
			when s0=>
				if cen='1' then
					regAux := cmdTrack_0;
					seq_ack_0 := '1';
					state:=s1;
				end if;
			
			when s1=>
				if keyboard_ack='1' then
					state:=s2;
				end if;
				
			when s2=>
				if cen='1' then
					regAux := cmdTrack_1;
					seq_ack_1 := '1';
					state:=s3;
				end if;

			when s3=>
				if keyboard_ack='1' then
					state:=s0;
				end if;
				
		end case;			
	
    end if;
end process;
  
end Behavioral;
