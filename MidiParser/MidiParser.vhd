----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: MidiParser.vhd - Behavioral
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
--		-- For Midi parser component --
--		Format of mem_CmdReadRequest	:	cmd(24 downto 0) = 4bytes addr to read,  
--									 	
--										cmd(26 downto 25) = "00" -> cmd from byteProvider_0
--									                   
--								    	cmd(26 downto 25) = "01" -> cmd from byteProvider_1
--					                                   
--										cmd(26 downto 25) = "11" -> cmd from OneDividedByDivisionProvider
--
--
--
--		-- For Midi parser component --
--		Format of mem_CmdReadResponse :	If requestComponent is byteProvider_0 or byteProvider_1
--											cmd(127 downto 0) = bytes readed for 16 bytes addr, use first 23 bits of addr 
--									 	else
--											cmd(127 downto 32) = (others=>'0')
--											cmd(31 downto 0) = bytes readed for 4 bytes addr, use first 25 bits of addr
--						
--									 	cmd(129 downto 128) = "00" -> cmd from byteProvider_0
--										              
--								     	cmd(129 downto 128) = "01" -> cmd from byteProvider_1
--					                                  
--										cmd(129 downto 128) = "11" -> cmd from OneDividedByDivisionProvider
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

entity MidiParser is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;

        -- Host
		cen							:	in	std_logic;
		readMidifileRqt				:	in	std_logic;
		fileOk						:	out	std_logic;
		OnOff						:	out	std_logic;
        
        --Debug
        statesOut_MidiCntrl         :   out std_logic_vector(4 downto 0);
        
        -- Keyboard side
		keyboard_ack	            :	in	std_logic; -- Request of a new command
        aviableCmd                  :   out std_logic;    
        cmdKeyboard                 :   out std_logic_vector(9 downto 0);

        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(129 downto 0);
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(26 downto 0); 
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
attribute   dont_touch    :   string;
attribute   dont_touch  of  MidiParser  :   entity  is  "true";
    
end MidiParser;

use work.my_common.all;

architecture Behavioral of MidiParser is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
	type    byteAddr_t  is array(0 to 1) of std_logic_vector(26 downto 0); 
	type    byteData_t  is array( 0 to 1 ) of std_logic_vector(7 downto 0);
	type    memAddr_t  is array( 0 to 1 ) of std_logic_vector(22 downto 0);
	type	trackAddrStart_t	is	array(0 to 1)	of	std_logic_vector(26 downto 0);
	
	type	tracksCmd_t	is	array(0 to 1)	of	std_logic_vector(9 downto 0);
    type    tempoValue_t   is array(0 to 1) of std_logic_vector(23 downto 0);
        
----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For Midi Controller component
	signal	muxBP_0	:	std_logic;

	-- For ODBD component
    signal  ODBD_ReadRqt, ODBD_readyVal 	:   std_logic;
	signal	divisionVal						:	std_logic_vector(15 downto 0); -- Input in ODBD component, used as output signal in Read Header Component
	signal	ODBD_Val						:	std_logic_vector(23 downto 0);
	signal	mem_ODBD_addr					:	std_logic_vector(24 downto 0);
	
	-- For ByteProvider components
	signal	BP_addr				:	byteAddr_t;
	signal	BP_data				:	byteData_t;
	signal	BP_byteRqt, BP_ack	:	std_logic_vector(1 downto 0);
	
	-- For Read Header components
	signal	readFinish, headerOKe, startHeaderRead		:	std_logic;
	signal	finishTracksRead, tracksOK	                :	std_logic_vector(1 downto 0);
	signal  readTracksRqt                               :   std_logic_vector(3 downto 0);
	signal	trackAddrStartVal							:	trackAddrStart_t;
	
	signal	BP_addr_ReadHeader							:	std_logic_vector(26 downto 0); 
	signal	BP_data_ReadHeader							:	std_logic_vector(7 downto 0);
	signal	BP_byteRqt_ReadHeader, BP_ack_ReadHeader	:	std_logic;
	signal  OnOffInter                                  :   std_logic;
	
	-- For Read Tracks components
	signal	BP_addr_ReadTrack_0							:	std_logic_vector(26 downto 0); 
	signal	BP_data_ReadTrack_0							:	std_logic_vector(7 downto 0);
	signal	BP_byteRqt_ReadTrack_0, BP_ack_ReadTrack_0	:	std_logic;
	signal  trackCmd                                    :   tracksCmd_t;
	
	signal  wrCmdRqt                                    :  std_logic_vector(1 downto 0);
	signal  sequencerAck                                :  std_logic_vector(1 downto 0);
	signal  updateTempoVal                              :  tempoValue_t;
	signal  updateTempoRqt, updateTempoAck              :  std_logic_vector(1 downto 0);
	
	signal  regCurrentTempo                             :  std_logic_vector(23 downto 0);
  
	-- For manage the mem CMDs
	signal	memAckSend, memAckResponse, memSamplesSendRqt	:	std_logic_vector(2 downto 0);
	signal	mem_byteP_addrOut								:	memAddr_t;
	
begin

----------------------------------------------------------------------------------
-- COMPONENTS
--		MidiController
--      Byte Provider components
--		OneDividedByDivision component
--		Read Header Component
--      Cmd Keyboard Sequencer
--		Read Track Components
----------------------------------------------------------------------------------  

-- Multiplexors for BP_0
	BP_addr(0) <= BP_addr_ReadHeader when muxBP_0='0' else BP_addr_ReadTrack_0;	
	BP_byteRqt(0) <= BP_byteRqt_ReadHeader when muxBP_0='0' else BP_byteRqt_ReadTrack_0;
	
	BP_data_ReadHeader <= BP_data(0) when muxBP_0='0' else (others=>'0');
    BP_ack_ReadHeader <= BP_ack(0) when muxBP_0='0' else '0';
    
	BP_data_ReadTrack_0 <= BP_data(0) when muxBP_0='1' else (others=>'0');
    BP_ack_ReadTrack_0 <= BP_ack(0) when muxBP_0='1' else '0';

--------------------------------------------------------------------
-- MIDI CONTROLLER
--------------------------------------------------------------------
OnOff <=OnOffInter;
my_MidiController : MidiController
 port map( 
        rst_n           	=> rst_n,	
        clk             	=> clk,	
		cen					=> cen,
		readMidifileRqt		=> readMidifileRqt,	
		finishHeaderRead	=> readFinish,	
		headerOK			=> headerOKe,	
		finishTracksRead	=> finishTracksRead,	
		tracksOK			=> tracksOK,	
		ODBD_ValReady		=> ODBD_readyVal,	
								
		readHeaderRqt		=> startHeaderRead,
		muxBP_0				=> muxBP_0,
		readTracksRqt		=> readTracksRqt,	
		parseOnOff			=> OnOffInter,	
								
		--Debug                 
		statesOut       	=> statesOut_MidiCntrl	
		
  );

--------------------------------------------------------------------
-- BYTE PROVIDERS COMPONENTS 
--------------------------------------------------------------------
BP_0 : ByteProvider
  port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr(0),			
        byteRqt =>BP_byteRqt(0),  
        byteAck => BP_ack(0),            
        nextByte =>BP_data(0),
      
        -- Mem side
		dataIn       	    =>	mem_CmdReadResponse(127 downto 0),
        memAckSend       	=>	memAckSend(0),
        memAckResponse   	=>	memAckResponse(0),
        addr_out         	=>	mem_byteP_addrOut(0),    
		memSamplesSendRqt	=>	memSamplesSendRqt(0)

	);


BP_1 : ByteProvider
  port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr(1),			
        byteRqt =>BP_byteRqt(1),  
        byteAck => BP_ack(1),            
        nextByte =>BP_data(1),
      
        -- Mem arbitrator side
		dataIn       	    =>	mem_CmdReadResponse(127 downto 0),
        memAckSend       	=>	memAckSend(1),
        memAckResponse   	=>	memAckResponse(1),
        addr_out         	=>	mem_byteP_addrOut(1),    
		memSamplesSendRqt	=>	memSamplesSendRqt(1)

  );

--------------------------------------------------------------------
-- ONE DIVIDED BY DIVISON COMPONENT
--------------------------------------------------------------------
my_ODBD_Provider : OneDividedByDivision_Provider
  generic map(START_ADDR=>2844660) -- Address of 4Bytes of the first OneDividedByDivision constants stored in memory 
  port map( 
        rst_n           		=> rst_n,
        clk             		=> clk,
		readRqt					=> ODBD_ReadRqt,
		division				=> divisionVal,
		readyValue				=> ODBD_readyVal,
		OneDividedByDivision	=> ODBD_Val,
		 
		-- Mem arbitrator side
		dataIn       			=>	mem_CmdReadResponse(23 downto 0),
		memAckSend      		=>	memAckSend(2),		
		memAckResponse			=>	memAckResponse(2),
		addr_out        		=>	mem_ODBD_addr,    
		memConstantSendRq		=>	memSamplesSendRqt(2)

  );


-- Check if tracks and header are Ok
fileOk <= headerOKe and tracksOK(0) and tracksOK(1);

--------------------------------------------------------------------
-- READ HEADER CHUNK COMPONENT
--------------------------------------------------------------------
my_ReadHeaderChunk : ReadHeaderChunk
  generic map(START_ADDR=>11640784)--Address of the first byte of midi file ->((189644*30)+65535*2)*2+4
  port map( 
		rst_n => rst_n,
        clk => clk,
		cen => cen,                     
		readRqt => startHeaderRead,			
        finishRead => readFinish,  
        headerOk => headerOKe,
		
		-- OneDividedByDivision_Provider side
		ODBD_ReadRqt => ODBD_ReadRqt,
        division => divisionVal,
		
		-- Start addreses for the Read Trunk Chunk components
        track0AddrStart => trackAddrStartVal(0),
        track1AddrStart => trackAddrStartVal(1),
		 
		--Byte provider side
        nextByte => BP_data_ReadHeader,
        byteAck  => BP_ack_ReadHeader,
        byteAddr => BP_addr_ReadHeader,
        byteRqt  => BP_byteRqt_ReadHeader

  );

--------------------------------------------------------------------
-- CMD KEYBOARD SEQUENCER 
--------------------------------------------------------------------
CmdSequencer: CmdKeyboardSequencer
port map( 
    rst_n                 => rst_n,           
    clk                   => clk,
    
    -- Read Tracks Side   
    cmdIn_0               => trackCmd(0),
    cmdIn_1               => trackCmd(1),
    sendCmdRqt            => wrCmdRqt,
    seq_ack               => sequencerAck,
    
    --Keyboard side       
    keyboard_ack          => keyboard_ack,
    aviableCmd            => aviableCmd,
    cmdKeyboard           => cmdKeyboard
);

--------------------------------------------------------------------
-- READ TRACKS COMPONENTS
--------------------------------------------------------------------
my_currentTempo:
process(rst_n,clk,updateTempoRqt,OnOffInter)
    variable    turn    :   boolean;

begin
    if rst_n='0' then
        regCurrentTempo <=std_logic_vector(to_unsigned(500000,24)); -- Following the midi standard
        updateTempoAck <=(others=>'0');
        turn := true;
        
    elsif rising_edge(clk) then
        updateTempoAck <=(others=>'0');
        
        if OnOffInter='1' then
            if updateTempoRqt(0)='1' or updateTempoRqt(1)='1' then
                if turn and updateTempoRqt(0)='1' then
                    updateTempoAck(0) <='1';
                    regCurrentTempo <=updateTempoVal(0);
                elsif not turn and updateTempoRqt(1)='1' then
                    updateTempoAck(1) <='1';
                    regCurrentTempo <=updateTempoVal(1);
                end if;
                turn := not turn;
            end if;
            
         elsif unsigned(regCurrentTempo)/=to_unsigned(500000,24) then
            regCurrentTempo <=std_logic_vector(to_unsigned(500000,24)); -- Following the midi standard
        end if; --OnOffInter='1'
        
    end if;
end process my_currentTempo;



ReadTrackChunk_0 : ReadTrackChunk
  port map( 
        rst_n           		=> rst_n,	
        clk             		=> clk,	
        cen                 	=> cen,    
		readRqt					=> readTracksRqt(1 downto 0),	
		trackAddrStart			=> trackAddrStartVal(0),	
		OneDividedByDivision	=> ODBD_Val,
		
      -- Tempo
        currentTempo            => regCurrentTempo,
        updateTempoAck          => updateTempoAck(0),
        updateTempoRqt          => updateTempoRqt(0),
        updateTempoVal          => updateTempoVal(0),
		
        -- Read status
		finishRead				=> finishTracksRead(0),	
		trackOK					=> tracksOK(0),	
		
        -- CMD Keyboard interface
        sequencerAck            => sequencerAck(0),
        wrCmdRqt                => wrCmdRqt(0),
        cmd                     => trackCmd(0),
  
								
		--Byte provider side	    
		nextByte        		=> BP_data_ReadTrack_0,
		byteAck					=> BP_ack_ReadTrack_0,	
		byteAddr        		=> BP_addr_ReadTrack_0,	
		byteRqt					=> BP_byteRqt_ReadTrack_0	
	
  );


ReadTrackChunk_1 : ReadTrackChunk
  port map( 
        rst_n           		=> rst_n,	
        clk             		=> clk,	
        cen                 	=> cen,    
		readRqt					=> readTracksRqt(3 downto 2),	
		trackAddrStart			=> trackAddrStartVal(1),	
		OneDividedByDivision	=> ODBD_Val,
		
        -- Tempo
        currentTempo            => regCurrentTempo,
        updateTempoAck          => updateTempoAck(1),
        updateTempoRqt          => updateTempoRqt(1),
        updateTempoVal          => updateTempoVal(1),

        -- Read status	
		finishRead				=> finishTracksRead(1),	
		trackOK					=> tracksOK(1),	

        -- CMD Keyboard interface
        sequencerAck            => sequencerAck(1),
        wrCmdRqt                => wrCmdRqt(1),
        cmd                     => trackCmd(1),
								
		--Byte provider side	    
		nextByte        		=> BP_data(1),
		byteAck					=> BP_ack(1),	
		byteAddr        		=> BP_addr(1),	
		byteRqt					=> BP_byteRqt(1)	
	
  );


----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(rst_n,clk,cen,mem_emptyBuffer,mem_CmdReadResponse)
begin
    -- Everything in one cycle
    
    -- Read order to response buffer, read send response  
    mem_readResponseBuffer <= '0'; 
    memAckResponse <=(others=>'0');
    if cen='0' and mem_emptyBuffer='0' then        
        mem_readResponseBuffer <= '1';
        if mem_CmdReadResponse(129 downto 128)="11" then
            memAckResponse(2) <='1';
        else
            memAckResponse(to_integer( unsigned(mem_CmdReadResponse(129 downto 128)) )) <='1';
        end if;    
    end if;

end process fsmResponse;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,cen,memSamplesSendRqt)    
    variable turnCntr   	:   unsigned(1 downto 0);
    variable regReadCmdRqt 	:   std_logic_vector(26 downto 0);
    
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;
  
    if rst_n='0' then
       turnCntr := (others=>'0');
       regReadCmdRqt := (others=>'0');
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0'); 
               
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
        memAckSend <=(others=>'0'); -- Just one cycle
                
        if cen='0' and memSamplesSendRqt(to_integer(turnCntr))='1' then
            -- Write command in the mem buffer
            mem_writeReciveBuffer <= '1';
            -- Send Ack to provider
            memAckSend(to_integer(turnCntr)) <='1';
            -- Build cmd
            if turnCntr=2 then
                regReadCmdRqt := "11" & mem_ODBD_addr; -- ODBD index + ODBD addr
            else
                regReadCmdRqt := std_logic_vector(turnCntr) & mem_byteP_addrOut(to_integer(turnCntr)) & "00"; -- provider index + provider addr
            end if;
            
        end if;
    
        if turnCntr=2 then -- Until max providers
            turnCntr := (others=>'0');
        else
            turnCntr := turnCntr+1;
        end if;             

        
    end if;--rst_n/rising_edge
end process fsmSend;
  
end Behavioral;