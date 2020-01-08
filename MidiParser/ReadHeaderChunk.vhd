----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ReadHeaderChunk - Behavioral
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

entity ReadHeaderChunk is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		readRqt			:	in	std_logic; -- One cycle high to request a read
		finishRead		:	out std_logic; -- One cycle high when the component end to read the header
		headerOk		:	out std_logic; -- High, if the header follow our requirements
		division		:	out std_logic_vector(15 downto 0);
		
		--Byte provider side
		nextByte        :   in  std_logic_vector(7 downto 0);
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteRqt			:	out std_logic -- One cycle high to request a new byte

  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ReadHeaderChunk  :   entity  is  "true";
    
end MilisecondDivisor;
architecture Behavioral of ReadHeaderChunk is

	constant HEADER_CHUNK_MARK : std_logic_vector(31 downto 0) := X"4d546864";
	constant HEADER_LENGTH	: std_logic_vector(31 downto 0) := X"00000006";
	constant HEADER_FORMAT	: std_logic_vector(32 downto 0) := X"0001";
	constant HEADER_NTRKS	: std_logic_vector(32 downto 0) := X"0002";
	
begin

fsm:
process(rst_n,clk,cen)
    type states is (s0, s1, s2, s3, s4, s5);	
	variable state	:	states;
	variable regAux	:	std_logic_vector(31 downto 0);
	variable regDivision : std_logic_vector(15 downto 0);
	variable cntr	:	unsigned(2 downto 0);
	
begin
	division <=regDivision;
	
	if rst_n='0' then
		state := s0;
		regDivision := (others=>'0');
		regAux := (others=>'0');
		cntr := (others=>'0');
		headerOk <='0';
		finishRead <='0';
		byteRqt <='0';
		
    elsif rising_edge(clk) then
		finishRead <='0';
		byteRqt <='0';
		
		case state is
			when s0=>
				if readRqt='1' then
					headerOk<='0'; -- By default the header dosen't follow our requirements
					byteRqt <='1';
					state := s1;
				end if;
			
			when s1 =>
				if byteAck='1' then
					if cntr < 4 then 
						regAux <= regAux(23 downto 0) & nextByte;
						cntr := cntr+1;
						byteRqt <='1';
					else
						cntr :=(others=>'0');
						if regAux=HEADER_CHUNK_MARK then
							state := s2;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if
				end if; --byteAck='1'

			when s2 =>
				if byteAck='1' then
					if cntr < 4 then 
						regAux <= regAux(23 downto 0) & nextByte;
						cntr := cntr+1;
						byteRqt <='1';
					else
						cntr :=(others=>'0');
						if regAux=HEADER_LENGTH then
							state := s3;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if
				end if;


			when s3 =>
				if byteAck='1' then
					if cntr < 2 then 
						regAux <= regAux(23 downto 0) & nextByte;
						cntr := cntr+1;
						byteRqt <='1';
					else
						cntr :=(others=>'0');
						if regAux(15 downto 0)=HEADER_FORMAT then
							state := s4;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if
				end if;

			when s4 =>
				if byteAck='1' then
					if cntr < 2 then 
						regAux <= regAux(23 downto 0) & nextByte;
						cntr := cntr+1;
						byteRqt <='1';
					else
						cntr :=(others=>'0');
						if regAux(15 downto 0)=HEADER_NTRKS then
							state := s5;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if
				end if;

			when s5 =>
				if byteAck='1' then
					if cntr < 2 then 
						regDivision <= regDivision(15 downto 8) & nextByte;
						cntr := cntr+1;
						byteRqt <='1';
					else
						cntr :=(others=>'0');
						finishRead <='1';
						headerOk <='1';
						state := s0;
						end if;
					end if
				end if;


		end case;
	
end process;
  
end Behavioral;
