----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ReadTrackChunk - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.5
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

entity ReadTrackChunk is
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		trackAddrStart			:	in std_logic_vector(26 downto 0);
		--OneDividedByDivision	:	in std_logic_vector(26 downto 0);
		finishRead				:	out std_logic; -- One cycle high when the component end to read the header
		notesOn					:	out std_logic_vector(87 downto 0);
				
		--Debug		
		regAuxOut       		: out std_logic_vector(31 downto 0);
		cntrOut         		: out std_logic_vector(2 downto 0);
		statesOut       		: out std_logic_vector(7 downto 0);
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ReadHeaderChunk  :   entity  is  "true";
end ReadTrackChunk;

architecture Behavioral of ReadTrackChunk is

	constant TRACK_CHUNK_MARK : std_logic_vector(31 downto 0) := X"4d54726b";
	
	--Meta events
	constant META_EVENT_MARK	: std_logic_vector(7 downto 0) := X"ff";
	constant META_EVENT_END_OF_TRACK	: std_logic_vector(7 downto 0) := X"2f";
--	constant META_EVENT_SET_TEMPO	: std_logic_vector(7 downto 0) := X"51";

	--Mtrk events
	constant MTRK_EVENT_NOTE_ON	: std_logic_vector(7 downto 0) := X"09";		
	constant MTRK_EVENT_NOTE_OFF	: std_logic_vector(7 downto 0) := X"08";
	constant MTRK_EVENT_PC	: std_logic_vector(7 downto 0) := X"0c";
	constant MTRK_EVENT_CKP	: std_logic_vector(7 downto 0) := X"0d";
	
	constant MTRK_EVENT_CC	: std_logic_vector(7 downto 0) := X"0b";		
	constant CC_SUSTAIN	: std_logic_vector(7 downto 0) := X"40";

	--Sysex event
	constant SYSEX_EVENT_0	: std_logic_vector(7 downto 0) := X"f0";		
	constant SYSEX_EVENT_1	: std_logic_vector(7 downto 0) := X"f7";
	
-- Signals	
	signal deltaTime	:	std_logic_vector(63 downto 0);
	signal fsmByteRqt	:	std_logic;
	signal deltaTimeByteRqt	:	std_logic;
	signal readVarLengthRqt	:	std_logic;

	
begin

byteRqt <= fsmByteRqt or deltaTimeByteRqt;

readVarLEnghtData: ReadVarLength
  port map( 
        rst_n   	=> rst_n,
        clk     	=> clk,
        readRqt		=> readVarLengthRqt,
		valOut		=> deltaTime,
		dataRdy		=> deltaTimeRdy,
	
		--Byte provider side
		nextByte	=>nextByte,
		byteAck		=>byteAck,
		byteRqt		=>deltaTimeByteRqt,
  );

fsm:
process(rst_n,clk,readRqt,byteAck)
    type states is (s0, s1, s2, s3, s4, s5, s6, s7);	
	variable state	:	states;
	variable regNotesOn	:	std_logic_vector(87 downto 0);
	variable regWait	:	std_logic_vector(63 downto 0);
	variable aux1, aux2		:	std_logic_vector(63 downto 0);
	
begin
	
	notesOn <= regNotesOn;
	
	
	-- Calculate ms to wait 
	--deltaTime*(500000/480)/1000 precalculado para testear
	aux1 <= deltaTime * X"411AAAA‬"; -- Q64.16= Q64.0 * Q12.16, trunco
	aux2 <= aux1(63 downto 48) * X"0000041"; -- Q60.16= Q48.0 * Q12.16
	‬
    --Debug    
    statesOut <=(others=>'0');
    if state=s0 then
        statesOut(0)<='1'; 
    end if;
    
    if state=s1 then
        statesOut(1)<='1'; 
    end if;

    if state=s2 then
        statesOut(2)<='1'; 
    end if;

    if state=s3 then
        statesOut(3)<='1'; 
    end if;

    if state=s4 then
        statesOut(4)<='1'; 
    end if;

    if state=s5 then
        statesOut(5)<='1'; 
    end if;

    if state=s6 then
        statesOut(6)<='1'; 
    end if;

    if state=s7 then
        statesOut(7)<='1'; 
    end if;

    --
    	
	if rst_n='0' then
		regDeltaTimeVal := (others=>'0');
		state := s0;
		finishRead <='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';
		
    elsif rising_edge(clk) then
		finishRead <='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';

		case state is
			when s0=>
				if readRqt='1' then
					regAddr := trackAddrStart;
					fsmByteRqt <='1';
					state := s1;
				end if;
			
			-- Check TRACK_CHUNK_MARK
			when s1 =>
                if cntr < 4 then 
                    if byteAck='1' then
						
						if cntr < 3 then
                          fsmByteRqt <='1';
                        end if;
                        
						regAux := regAux(23 downto 0) & nextByte;
						regAddr := regAddr+1;
						cntr := cntr+1;
					end if;
                else
                    cntr :=(others=>'0');
                    if regAux=TRACK_CHUNK_MARK then
                        regAddr := regAddr + 4; -- Avoid track length information 
						readVarLengthRqt <='1';
                        state := s2;
                    else
                        finishRead <='1';
                        state := s0;
                    end if;
                end if;
				
			-- Get the time to wait before processing the midi command                
			when s2 =>
                if deltaTimeRdy='1' then 
					regWait <= ‬aux2(63 downto 48); 
					state := s3;
                end if;
            
			-- Wait delta time value in ms before execute command
			when s3 =>
				if regWait=0 then  
					state := s4;
				elsif TCmili='1' then
					regWait := regWait-1;
				end if;
			
			-- Read command
			when s4 =>
				
			when s5 =>
		  
			when s6 =>
			
			when s7 =>
		  
		  end case;
		
    end if;
end process;
  
end Behavioral;
