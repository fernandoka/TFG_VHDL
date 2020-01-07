----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ByteProvider - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ByteProvider is
  Generic(START_ADDR : in natural);
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		addrInVal		:	in	std_logic_vector(25 downto 0); -- Byte addres
		byteRqt			:	in	std_logic; -- One cycle high to request a new byte
		
		byteAck			:	out	std_logic; -- One cycle high to notify the reception of a new byte
		nextByte        :   out	std_logic_vector(7 downto 0);
		
		-- Mem side
		mem_ack			:	in	std_logic;
		mem_dataIn		:	in	std_logic_vector(127 downto 0);
		
		mem_readRqt_n		:	out std_logic; -- Active low
		mem_addr		:	out std_logic_vector(22 downto 0)
		
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ByteProvider  :   entity  is  "true";
    
end ByteProvider;
architecture Behavioral of ByteProvider is

begin

fsm:
process(rst_n,clk,readRqt,byteAck)
    type states is (serveBytes, mem_waitAck);	
	variable state		:	states;
	variable regAddr	:	unsigned(25 downto 0);	
	variable regData	:	std_logic_vector(127 downto 0);
begin
    
	mem_addr <= regAddr(22 downto 0);
    
	if rst_n='0' then
		state := serveBytes;
		regAddr := to_unsigned(START_ADDR,26);
		regData := (others=>'0');
		byteAck <='0';
		mem_readRqt_n <= '1';
		
    elsif rising_edge(clk) then
		byteAck <='0';
		mem_readRqt_n <= '1';
			
		case state is
			when serveBytes=>
				if readRqt='1' then
					if (addrInVal < regAddr+16) or (addrInVal > regAddr+16) then
						regAddr <= addrInVal;
						mem_readRqt <= '0';
						state := mem_waitAck;
					else
						byteAck <= '1';
						case addrInVal(3 downto 0)
							when X"0"=>
								nextByte <= regData(7 downto 0);

							when X"1"=>
								nextByte <= regData(15 downto 8);

							when X"2"=>
								nextByte <= regData(23 downto 16);

							when X"3"=>
								nextByte <= regData(31 downto 24);

							when X"4"=>
								nextByte <= regData(39 downto 32);

							when X"5"=>
								nextByte <= regData(47 downto 40);

							when X"6"=>
								nextByte <= regData(55 downto 48);

							when X"7"=>
								nextByte <= regData(63 downto 56);								

							when X"8"=>
								nextByte <= regData(71 downto 64);

							when X"9"=>
								nextByte <= regData(79 downto 72);

							when X"A"=>
								nextByte <= regData(87 downto 80);

							when X"B"=>
								nextByte <= regData(95 downto 88);

							when X"C"=>
								nextByte <= regData(103 downto 96);

							when X"D"=>
								nextByte <= regData(111 downto 104);

							when X"E"=>
								nextByte <= regData(119 downto 112);

							when X"F"=>
								nextByte <= regData(127 downto 120);
							
							when others=>
								nextByte <= (others=>'0');
					end if;
				end if;
			
			when mem_waitAck =>
				if mem_ack='1' then
					regData := mem_dataIn;
					state := serveBytes;
				end if;

		end case;
    end if;
end process;
  
end Behavioral;
