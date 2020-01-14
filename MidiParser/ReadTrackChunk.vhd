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
----------------------------- Constants --------------------------------------------

	constant TRACK_CHUNK_MARK : std_logic_vector(31 downto 0) := X"4d54726b";
	
	--Meta events
	constant META_EVENT_MARK			: std_logic_vector(7 downto 0) := X"ff";
	constant META_EVENT_END_OF_TRACK	: std_logic_vector(7 downto 0) := X"2f";
	constant META_EVENT_SET_TEMPO		: std_logic_vector(7 downto 0) := X"51";
	constant META_EVENT_TIME_SIGNATURE	: std_logic_vector(7 downto 0) := X"58";
	constant META_EVENT_KEY_SIGNATURE	: std_logic_vector(7 downto 0) := X"59";
	
	--Mtrk events
	constant MTRK_EVENT_NOTE_ON	: std_logic_vector(7 downto 0) := X"90";		
	constant MTRK_EVENT_NOTE_OFF	: std_logic_vector(7 downto 0) := X"80";
	constant MTRK_EVENT_PC	: std_logic_vector(7 downto 0) := X"c0";
	constant MTRK_EVENT_CKP	: std_logic_vector(7 downto 0) := X"d0";
	
	constant MTRK_EVENT_CC	: std_logic_vector(7 downto 0) := X"b0";		
	constant CC_SUSTAIN	: std_logic_vector(7 downto 0) := X"40";

	--Sysex event
	constant SYSEX_EVENT_0	: std_logic_vector(7 downto 0) := X"f0";		
	constant SYSEX_EVENT_1	: std_logic_vector(7 downto 0) := X"f7";
	
----------------------------- Signals --------------------------------------------
	--fsm
	signal fsmByteRqt	:	std_logic;
	signal fsmAddr		:	std_logic_vector(26 downto 0);
	signal muxByteAddr	:	std_logic;
	
	-- ReadVarLength
	signal deltaTime			:	std_logic_vector(63 downto 0);
	signal deltaTimeByteAddr	:	std_logic_vector(26 downto 0);
	signal deltaTimeByteRqt		:	std_logic;
	signal readVarLengthRqt		:	std_logic;
	
	--msDivisor
	signal TCmili, cenDivisor	:	std_logic;
	
begin

byteAddr <= fsmAddr when muxByteAddr='0' else deltaTimeByteAddr;
byteRqt <= fsmByteRqt or deltaTimeByteRqt;


readVarLEnghtData: ReadVarLength
  port map( 
        rst_n   	=> rst_n,
        clk     	=> clk,
        readRqt		=> readVarLengthRqt,
		iniAddr		=> fsmAddr,
		valOut		=> deltaTime,
		dataRdy		=> deltaTimeRdy,
	
		--Byte provider side
		nextByte	=> nextByte,
		byteAck		=> byteAck,
		byteAddr	=> deltaTimeByteAddr,
		byteRqt		=> deltaTimeByteRqt,
  );


msDivisor: MilisecondDivisor is
  generic map(FREQ =>75000);-- Frequency in Khz
  port map( 
        rst_n   => rst_n,
        clk     => clk,
		cen		=> cenDivisor,
		Tc		=> TCmili
		
  );


fsm:
process(rst_n,clk,readRqt,byteAck,deltaTimeByteRqt)
    type states is (s0, s1, s2, s3, s4, s5, skipVarLengthBytes, resolveMetaEvent, s7);	
	variable state	:	states;
	
	variable regAddr : unsigned(26 downto 0);
	variable regNotesOn	:	std_logic_vector(87 downto 0);
	variable regWait	:	unsigned(63 downto 0);
	variable aux1, aux2		:	unsigned(63 downto 0);
	
	variable runningStatus	:	std_logic_vector(7 downto 0);
begin
	
	notesOn <= regNotesOn;
	fsmAddr <=std_logic_vector(regAddr);
	
	-- Moore output
	
	-- Enable readVarLegth component
	muxByteAddr <='0';
	if state=s2 or resolveSysExEventthen
		muxByteAddr <='1';
	end if;
	
	-- Enable msDivisor
	cenDivisor <='0';
	if state=s3 then
		cenDivisor <='1';
	end if;
	
	-- Calculate ms to wait, aprox 
	-- deltaTime*(500000/480)/1000 precalculado para testear
	-- trunco no tengo en cuenta el overflow ni el underflow, confio en que con 64 bits nunca se excedera la resolucion
	aux1 <= unsigned(deltaTime) * unsigned(X"411AAAA‬"); -- Q64.16= Q64.0 * Q12.16, 
	aux2 <= unsigned(aux1(63 downto 16)) * unsigned(X"0000041"); -- Q60.16= Q48.0 * Q12.16
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

    if state=resolveSysExEvent then
        statesOut(6)<='1'; 
    end if;

    if state=resolveMetaEvent_0 then
        statesOut(7)<='1'; 
    end if;

    --
    	
	if rst_n='0' then
		regDeltaTimeVal := (others=>'0');
		runningStatus := (others=>'0');
		regAddr := (others=>'0');
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
			
			-- MAIN LOOP STARTS IN THIS STATE (s2)
			-- Event Parser Starts in this state, first read delta time	
			-- Get the time to wait before processing the midi command                
			when s2 =>
                if deltaTimeRdy='1' then 
					regWait <= ‬unsigned(aux2(63 downto 16));
					regAddr := deltaTimeByteAddr; -- Update the value of the current addr					
					state := s3;
                end if;
            
			-- Wait delta time value in ms before execute command
			when s3 =>
				if regWait=0 then
					regAddr := regAddr+1;
					fsmByteRqt <='1';
					state := s4;
				elsif TCmili='1' then
					regWait := regWait-1;
				end if;
			
			-- Read one byte and decide if is a status byte or not
			-- If is a status byte, running status will change
			-- If not, 2 reads of the same byte would be order
			when s4 =>
				if byteAck='1' then
					if nextByte(7)='1' then 
						regAddr := regAddr+1;
						runningStatus := nextByte;						
					end if;
					state := s5;
				end if;
			
			-- Decision state
			when s5 =>
				if runningStatus=META_EVENT_MARK then
					fsmByteRqt <='1';
					status := resolveMetaEvent;
				elsif runningStatus=SYSEX_EVENT_0 or runningStatus=SYSEX_EVENT_1 then
					readVarLengthRqt <='1';
					status := skipVarLengthBytes;
				else
					-- Actions to perform on the keyboard
					if runningStatus=MTRK_EVENT_NOTE_ON  then
						
					elsif runningStatus=MTRK_EVENT_NOTE_OFF then
						
					elsif runningStatus=MTRK_EVENT_CKP or runningStatus=MTRK_EVENT_PC then
						regAddr := regAddr+1;
						status := s2;
					else
						regAddr := regAddr+2;
						status := s2;
					end if;
				end if;

			when resolveMetaEvent =>
				if byteAck='1' then
					if nextByte/=META_EVENT_END_OF_TRACK then
						readVarLengthRqt <='1';
						state := skipVarLengthBytes;
					else
						finishRead <='1';
						state := s0;
					end if;
				end if;
		  
			when skipVarLengthBytes =>
				if deltaTimeRdy='1' then
					regAddr := deltaTimeByteAddr + deltaTime; -- El nº de bytes que ocupa el evento apartir de la ultima direccion leida por readVarLength. 
					readVarLengthRqt <='1';
					state := s2;
				end if;


			when resolveMidiEvent =>
				if deltaTimeRdy='1' then
					regAddr := deltaTimeByteAddr + deltaTime; -- El nº de bytes que ocupa el evento apartir de la ultima direccion leida por readVarLength. 
					readVarLengthRqt <='1';
					state := s2;
				end if;
		  
		  end case;
		
    end if;
end process;
  
end Behavioral;
