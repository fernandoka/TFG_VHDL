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
-- Revision 0.7
-- Additional Comments:
--      It seems is working properly
--		if readRqt(0) read will be done in check mode, and no waiting time no commands to the keyboard will be send.
--		if readRqt(1) read will be done in play mode,  commands to the keyboard will be send and waiting time will be enable.
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
		readRqt					:	in	std_logic_vector(1 downto 0); -- One cycle high to request a read 
		trackAddrStart			:	in std_logic_vector(26 downto 0); -- Must be stable for the whole read
		--OneDividedByDivision	:	in std_logic_vector(26 downto 0);
		finishRead				:	out std_logic; -- One cycle high to notify the end of track reached
		trackOK					:	out	std_logic; -- High track data is ok, low track data is not ok			
		notesOn					:	out std_logic_vector(87 downto 0);
				
		--Debug		
		regAuxOut       		: out std_logic_vector(31 downto 0);
		regAddrOut          	: out std_logic_vector(26 downto 0);
		statesOut       		: out std_logic_vector(8 downto 0);
		runningStatusOut        : out std_logic_vector(7 downto 0);  
		dataBytesOut            : out std_logic_vector(15 downto 0);
		regWaitOut              : out std_logic_vector(47 downto 0);
		 
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

component ReadVarLength is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        readRqt			:	in	std_logic; -- One cycle high to request a read
        iniAddr			:	in	std_logic_vector(26 downto 0);
        valOut			:	out	std_logic_vector(63 downto 0);
        dataRdy			:	out std_logic;  -- One cycle high when the data is ready

		--Byte provider side
		nextByte        :   in  std_logic_vector(7 downto 0);
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
        byteAddr		:	out std_logic_vector(26 downto 0);
		byteRqt			:	out std_logic -- One cycle high to request a new byte
  ); 
end component;


component MilisecondDivisor is
  Generic(FREQ : in natural);-- Frequency in Khz
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		cen				:	in	std_logic;
		Tc				:	out std_logic
		
  );
end component;

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
	
	--Op constants
	constant OP1   :   unsigned(27 downto 0) := X"411AAAA";
	constant OP2   :   unsigned(27 downto 0) := X"0000041";

----------------------------- Signals --------------------------------------------
	--fsm
	signal fsmByteRqt	:	std_logic;
	signal fsmAddr		:	std_logic_vector(26 downto 0);
	signal muxByteAddr	:	std_logic;
	
	--ReadVarLength
	signal resVarLength			:	std_logic_vector(63 downto 0);
	signal varLengthByteAddr	:	std_logic_vector(26 downto 0);
	signal varLengthByteRqt		:	std_logic;
	signal readVarLengthRqt		:	std_logic;
	signal varLengthRdy			:	std_logic;
	
	--msDivisor
	signal TCmili, cenDivisor	:	std_logic;
	
begin

byteAddr <= fsmAddr when muxByteAddr='0' else varLengthByteAddr;
byteRqt <= fsmByteRqt or varLengthByteRqt;


readVarLEnghtData: ReadVarLength
  port map( 
        rst_n   	=> rst_n,
        clk     	=> clk,
        readRqt		=> readVarLengthRqt,
		iniAddr		=> fsmAddr,
		valOut		=> resVarLength,
		dataRdy		=> varLengthRdy,
	
		--Byte provider side
		nextByte	=> nextByte,
		byteAck		=> byteAck,
		byteAddr	=> varLengthByteAddr,
		byteRqt		=> varLengthByteRqt
  );


msDivisor: MilisecondDivisor
  generic map(FREQ =>75)-- Frequency in Khz
  port map( 
        rst_n   => rst_n,
        clk     => clk,
		cen		=> cenDivisor,
		Tc		=> TCmili
		
  );


fsm:
process(rst_n,clk,readRqt,byteAck,varLengthRdy)
    type modes is (check, play);
	type states is (s0, s1, s2, s3, s4, s5, s6, skipVarLengthBytes, resolveMetaEvent, readEventData);	
	type fsm_states is record
		state   :   states;
        mode   	:   modes;
	end record;
	variable fsm_state	:	fsm_states;
	
	variable regAddr        :	unsigned(26 downto 0);
	variable regNotesOn     :	std_logic_vector(87 downto 0);
	variable regWait	    :	unsigned(47 downto 0);
	
	variable aux1           : unsigned(91 downto 0); -- These sizes because simulation tool
	variable aux2		    : unsigned(75 downto 0); -- These sizes because simulation tool
	variable  readedBytes   : unsigned(26 downto 0);
	
	variable regAux         :   std_logic_vector(31 downto 0);
	variable runningStatus	:	std_logic_vector(7 downto 0);
	variable dataBytes		:	std_logic_vector(15 downto 0);
	variable cntr           :   unsigned(2 downto 0);
begin
	
	notesOn <= regNotesOn;
	fsmAddr <= std_logic_vector(regAddr);
		
	-------------------
	-- Moore outputs --
	-------------------
	-- Enable readVarLegth component
	muxByteAddr <='0';
	if fsm_state.state=s3 or fsm_state.state=skipVarLengthBytes then
		muxByteAddr <='1';
	end if;
	
	-- Enable msDivisor
	cenDivisor <='0';
	if fsm_state.state=s4 then
		cenDivisor <='1';
	end if;
	
	-- Calculate ms to wait, aprox 
	-- deltaTime*(500000/480)/1000 precalculado para testear
	-- trunco no tengo en cuenta el overflow ni el underflow, confio en que con 64 bits nunca se excedera la resolucion
	aux1 := unsigned(resVarLength) * OP1; -- Q64.16= Q64.0 * Q12.16, 
	aux2 := aux1(63 downto 16) * OP2; -- Q60.16= Q48.0 * Q12.16
	
    readedBytes := (regAddr - (unsigned(trackAddrStart) + 6)); -- 6 instead of 8 because don't count the ini and end byte address

    --Debug
    regAddrOut <= std_logic_vector(regAddr);
    regAuxOut <= regAux;
    runningStatusOut<=runningStatus;
    dataBytesOut<= dataBytes;
    regWaitOut<= std_logic_vector(regWait);
    
    statesOut <=(others=>'0');
    if fsm_state.state=s0 then
        statesOut(0)<='1'; 
    end if;
    
    if fsm_state.state=s1 then
        statesOut(1)<='1'; 
    end if;

    if fsm_state.state=s2 then
        statesOut(2)<='1'; 
    end if;

    if fsm_state.state=s3 then
        statesOut(3)<='1'; 
    end if;

    if fsm_state.state=s4 then
        statesOut(4)<='1'; 
    end if;

    if fsm_state.state=s5 then
        statesOut(5)<='1'; 
    end if;

    if fsm_state.state=skipVarLengthBytes then
        statesOut(6)<='1'; 
    end if;

    if fsm_state.state=resolveMetaEvent then
        statesOut(7)<='1'; 
    end if;

    if fsm_state.state=readEventData then
        statesOut(8)<='1'; 
    end if;
    --
    	
	if rst_n='0' then
		regWait := (others=>'0');
		runningStatus := (others=>'0');
		regAux := (others=>'0');
		regNotesOn := (others=>'0');
		regAddr := (others=>'0');
		dataBytes := (others=>'0');
		cntr := (others=>'0');
		fsm_state := (s0,check);
		finishRead <='0';
		trackOK<='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';
		
		
    elsif rising_edge(clk) then
		finishRead <='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';

		case fsm_state.state is
			when s0=>
                if readRqt(0)='1' then	
                    regAddr := unsigned(trackAddrStart);
                    fsm_state.mode := check;
                    fsmByteRqt <='1';
                    fsm_state.state := s1;                    
                    trackOK<='0';
                elsif readRqt(1)='1' then
                    regAddr := unsigned(trackAddrStart) + 8; -- Skip track mark and length data 
                    readVarLengthRqt <='1';
                    fsm_state.state := s3;                    
                    fsm_state.mode := play;
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
                        if fsm_state.mode=play then
							regAddr := regAddr + 4; -- Avoid track length information 
							readVarLengthRqt <='1';
							fsm_state.state := s3;
						else
							fsmByteRqt <='1';
							fsm_state.state := s2;
						end if;
                    
					else
                        finishRead <='1';
                        fsm_state.state := s0;
                    end if;
                end if;

			-- Save nº bytes of track
			when s2 =>
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
					readVarLengthRqt <='1';
					fsm_state.state := s3;
                end if;
				
			-----------------------------------------
			-- MAIN LOOP STARTS IN THIS STATE (s3) --
			-----------------------------------------
			-- Event Parser Starts in this state, first read delta time	
			-- Get the time to wait before processing the midi command                
			when s3 =>
                if varLengthRdy='1' then 
					regWait := unsigned(aux2(63 downto 16));
					regAddr := unsigned(varLengthByteAddr) + 1; -- Update the value of the current addr					
					if fsm_state.mode = check then
						fsmByteRqt <='1';
						fsm_state.state := s5;
					else
						fsm_state.state := s4;
					end if;
                end if;
            
			-- Wait delta time value in ms before execute command
			when s4 =>
				if regWait=0 then
					fsmByteRqt <='1';
					fsm_state.state := s5;
				elsif TCmili='1' then
					regWait := regWait-1;
				end if;
			
			-- Read one byte and decide if is a status byte or not
			-- If is a status byte, running status will change
			-- If not, runningStatus would not change, 
			-- one more read order of the same byte will be done in the nexts states
			when s5 =>
				if byteAck='1' then
					if nextByte(7)='1' then 
						regAddr := regAddr+1;
						runningStatus := nextByte;						
					end if;
					fsm_state.state := s6;
				end if;
			
			-- Decision state
			when s6 =>
				if runningStatus=META_EVENT_MARK then
					fsmByteRqt <='1';
					fsm_state.state := resolveMetaEvent;
				elsif runningStatus=SYSEX_EVENT_0 or runningStatus=SYSEX_EVENT_1 then
					readVarLengthRqt <='1';
					fsm_state.state := skipVarLengthBytes;
				else
					-----------------
					-- Midi events --
					-----------------
					if runningStatus=MTRK_EVENT_NOTE_OFF or runningStatus=MTRK_EVENT_NOTE_ON  then
						fsmByteRqt <='1';
						fsm_state.state := readEventData;
					-- The rest of midi events follow this pattern, skip those data bytes
					elsif runningStatus=MTRK_EVENT_CKP or runningStatus=MTRK_EVENT_PC then
						regAddr := regAddr+1;
                        readVarLengthRqt <='1';
						fsm_state.state := s3;
					else
						regAddr := regAddr+2;
                        readVarLengthRqt <='1';
						fsm_state.state := s3;
					end if;
				end if;

			when resolveMetaEvent =>
				if byteAck='1' then
					if nextByte/=META_EVENT_END_OF_TRACK then
						readVarLengthRqt <='1';
						regAddr := regAddr+1;
						fsm_state.state := skipVarLengthBytes;
					else
						finishRead <='1';
						-- Check if the length of the track is OK, only in check mode
						if fsm_state.mode=check and (readedBytes=unsigned(regAux)) then
							trackOK <='1';
						end if;
						fsm_state.state := s0; -- Finish of read track chunk
					end if;
				end if;
		  
			when skipVarLengthBytes =>
				if varLengthRdy='1' then
					-- Nº of bytes starting by the las address readed by VarLength component.
					regAddr := unsigned(varLengthByteAddr) + unsigned(resVarLength(26 downto 0)) + 1;  
					readVarLengthRqt <='1';
					fsm_state.state := s3;
				end if;


			when readEventData =>
				if cntr < 2 then 
					if byteAck='1' then
						
						if cntr < 1 then
							fsmByteRqt <='1';
						end if;

						dataBytes := dataBytes(7 downto 0) & nextByte;
                        regAddr := regAddr+1;
						cntr := cntr+1;
						
					end if;
				else
					-- Only send command when in play mode
					if fsm_state.mode=play and unsigned(dataBytes(15 downto 8)) >=21 and unsigned(dataBytes(15 downto 8)) <= 108 then
						if runningStatus=MTRK_EVENT_NOTE_OFF or (runningStatus=MTRK_EVENT_NOTE_ON and dataBytes(7 downto 0)=X"00") then
							regNotesOn(to_integer(unsigned(dataBytes(15 downto 8))-21)) :='0'; -- Note off
						else
							regNotesOn(to_integer(unsigned(dataBytes(15 downto 8))-21)) :='1'; -- Note on
						end if;
					end if;
					
					cntr :=(others=>'0');
                    readVarLengthRqt <='1';
					fsm_state.state := s3;
				end if;
		  
		  end case;
		
    end if;
end process;
  
end Behavioral;
