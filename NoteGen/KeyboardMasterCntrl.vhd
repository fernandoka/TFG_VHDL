----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: KeyboardMasterCntrl - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 1.1
-- Additional Comments:
--
--		-- For KeyboardCntrl --
--		Format of mem_CmdReadRequest :	cmd(25 downto 0) = sample addr to read 
--									 	
--										cmd(31 downto 26) = NoteGen index, the one which request a read
--										
--										cmd(32) = Keyboard Track index	
--
--		-- For KeyboardCntrl --
--		Format of mem_CmdReadResponse :	cmd(15 downto 0) = sample value 
--									 	
--										cmd(21 downto 16) = NoteGen index, the one which request a read
--
--										cmd(22) = Keyboard Track index
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

entity KeyboardMasterCntrl is
  Generic (NUM_GENS	:	in	natural);
  Port ( 
        rst_n           					:   in  std_logic;
        clk             					:   in  std_logic;
		
		aviableCmdTrack_0		            :	in  std_logic;	
		cmdKeyboardTrack_0					:	in  std_logic_vector(9 downto 0);
		aviableCmdTrack_1		            :	in  std_logic;	
		cmdKeyboardTrack_1					:	in  std_logic_vector(9 downto 0);
		keyboard_ack						:	out	std_logic_vector(1 downto 0);
		
		-- Debug
		numGensOn							:	out	std_logic_vector(4 downto 0);
		workingNotesGenOut					:	out	std_logic_vector(7 downto 0);
		--
		
		--IIS side		
        sampleRqt       					:   in  std_logic;
        sampleOut       					:   out std_logic_vector(15 downto 0);
        
        -- Mem side
		mem_emptyResponseBuffer				:	in	std_logic;
        mem_CmdReadResponse    				:   in  std_logic_vector(22 downto 0); 
        mem_fullReciveBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    		:   out std_logic_vector(32 downto 0);
		mem_readResponseBuffer				:	out std_logic;
        mem_writeReciveBuffer     			:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  KeyboardMasterCntrl  :   entity  is  "true";
end KeyboardMasterCntrl;

use work.my_common.all;

architecture Behavioral of KeyboardMasterCntrl is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
	type	samples_t	is array( 0 to 1 ) of std_logic_vector(15 downto 0); 
	type	numGensOn_t	is array( 0 to 1 ) of std_logic_vector(4 downto 0); 
	type	memsSignals_t	is array( 0 to 1 ) of std_logic_vector(NUM_GENS-1 downto 0);
	
	type	noteGenAddr_t	is array( 0 to NUM_GENS-1 ) of std_logic_vector(25 downto 0);
	type	noteGenAddrPerTrack_t	is array( 0 to 1 ) of noteGenAddr_t;
	type	noteGenAddrPerTrackRecive_t	is array( 0 to 1 ) of std_logic_vector(26*(NUM_GENS-1)+26 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
	
	signal	fsmsCe                  :	std_logic;
	signal	workingInter			:	std_logic_vector(7 downto 0);
	signal	samplePerKeyboardTrack	:	samples_t;
	signal	numGensOnPerTrack		:	numGensOn_t;
	
	signal	memAckResponsePerTrack, memAckSendPerTrack, memSamplesSendRqtPerTrack	:	memsSignals_t
	signal	notesGen_addrPerTrack													:	noteGenAddrPerTrack_t;
	signal	notesGen_addrPerTrackRecive												:	noteGenAddrPerTrackRecive_t;

begin


-- Debug
numGensOn <=std_logic_vector( unsigned(numGensOnPerTrack(0))+unsigned(numGensOnPerTrack(1)) );
workingNotesGenOut<= workingInter;
--

sum: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>samplePerKeyboardTrack(0),b_in=>samplePerKeyboardTrack(1),c_out=> sampleOut);

----------------------------------------------------------------------------------
-- KEYBOARD TRACK COMPONENTS
--      One Keyboard per track
----------------------------------------------------------------------------------

keyboardTrack_0: KeyboardTrackCntrl
  generic map(NUM_GENS =>NUM_GENS);
  port map( 
		rst_n           	=> rst_n,
		clk             	=> clk,
		cen               	=> cen,
		aviableCmd		    => aviableCmdTrack_0,      
		cmdKeyboard			=> cmdKeyboardTrack_0,
		keyboard_ack		=> keyboard_ack(0),
		
		--IIS side	             
		sampleRqt       	=> sampleRqt,
		sampleOut       	=> samplePerKeyboardTrack(0),
		
		--Debug                   
		numGensOn           => numGensOnPerTrack(0),      
		workingNotesGenOut  => workingInter(3 downto 0),
		--                       
		
		-- Notes Gen side      
		mem_CmdReadResponse	=> mem_CmdReadResponse(15 downto 0),
		memAckResponse      => memAckResponsePerTrack(0),      
		memAckSend			=> memAckSendPerTrack(0),
		memSamplesSendRqt   => memSamplesSendRqtPerTrack(0),
		notesGen_addrOut	=> notesGen_addrPerTrackRecive(0)

  );


keyboardTrack_1: KeyboardTrackCntrl
  generic map(NUM_GENS =>NUM_GENS);
  port map( 
		rst_n           	=> rst_n,
		clk             	=> clk,
		cen               	=> cen,
		aviableCmd		    => aviableCmdTrack_1,      
		cmdKeyboard			=> cmdKeyboardTrack_1,
		keyboard_ack		=> keyboard_ack(1),
		
		--IIS side	             
		sampleRqt       	=> sampleRqt,
		sampleOut       	=> samplePerKeyboardTrack(1),
		
		--Debug                   
		numGensOn           => numGensOnPerTrack(1),      
		workingNotesGenOut  => workingInter(7 downto 4),
		--                       
		
		-- Notes Gen side      
		mem_CmdReadResponse	=> mem_CmdReadResponse(15 downto 1),
		memAckResponse      => memAckResponsePerTrack(1),      
		memAckSend			=> memAckSendPerTrack(1),
		memSamplesSendRqt   => memSamplesSendRqtPerTrack(1),
		notesGen_addrOut	=> notesGen_addrPerTrackRecive(1)

  );



-- Internal ce signal for the FSMs, check if some note is working
cenForFsms: reducedOr
  generic map(WL=>NUM_GENS)
  port map(a_in=>workingInter, reducedA_out=>fsmsCe);

----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(fsmsCe,mem_emptyResponseBuffer,mem_CmdReadResponse)
begin
    -- Everything in the same cycle
    mem_readResponseBuffer <= '0';
    memAckResponse <=(others=>'0');
    if fsmsCe='1' and mem_emptyResponseBuffer='0' then
        memAckResponse(to_integer( unsigned(mem_CmdReadResponse(22)) ))(to_integer( unsigned(mem_CmdReadResponse(21 downto 16)) )) <='1';
        -- Read order to response buffer
        mem_readResponseBuffer <='1';
    end if; 
               
end process;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

assingNoteGenAddr:
for i in 0 to NUM_GENS-1 loop
	notesGen_addrPerTrack(0)(i) <= notesGen_addrPerTrackRecive(0)(26*i+25 downto 26*i);
	notesGen_addrPerTrack(1)(i) <= notesGen_addrPerTrackRecive(1)(26*i+25 downto 26*i);
end loop;


fsmSend:
process(rst_n,clk,fsmsCe,memSamplesSendRqtPerTrack,mem_fullReciveBuffer,notesGen_addrPerTrack)
    type states is ( checkGeneratorRqt, waitMemAck0);
    
    variable state      	:   states;
    variable turnGen   		:   unsigned(5 downto 0);
	variable turnTrack		:	unsigned(1 downto 0);
    variable regReadCmdRqt 	:   std_logic_vector(25+7 downto 0);
    
    variable addrPlusOne    :   unsigned(25 downto 0);
    variable flag           :   std_logic;
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;
    addrPlusOne := unsigned(regReadCmdRqt(25 downto 0))+1;
    
    if rst_n='0' then
       turnGen := (others=>'0');
	   turnTrack := (others=>'0');
       state := checkGeneratorRqt;
       regReadCmdRqt := (others=>'0');
       flag :='0';
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0');
	   
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
		memAckSend <=(others=>'0'); -- Just one cycle
        
		case state is
			
			-- Two Cmd per read request of a note generator
            when checkGeneratorRqt =>
                if fsmsCe='1' then
                    -- Wait one cycle to the previous write order take effect
                    if flag='0' then
                         if mem_fullReciveBuffer='0' then
                            if memSamplesSendRqtPerTrack(to_integer(turnTrack))(to_integer(turnGen))='1' then
								-- Build CMD, Track index + Note Gen index + sample addr
                                regReadCmdRqt := std_logic_vector(turnTrack(0)) & std_logic_vector(turnGen) & notesGen_addrPerTrack(to_integer(turnTrack))(to_integer(turnGen));
                                -- Write command in the mem buffer
                                mem_writeReciveBuffer <= '1';
                                -- Send ack to note gen
                                memAckSend(to_integer(turnTrack))(to_integer(turnGen)) <='1';
                                flag :=not flag;
                                state := waitMemAck0;
                            else
                                if turnGen=NUM_GENS-1 then -- Until max notes
                                    turnGen := (others=>'0');
									if turnTrack=1 then
										turnTrack :=(others=>'0');
									else
										turnTrack :=turnTrack+1;
									end if;
                                else
                                    turnGen := turnGen+1;
                                end if;
                            end if;
							
                        end if;--mem_fullReciveBuffer='0'  
                  else
                    flag := not flag;               
                  end if;
              end if; --fsmsCe='1'		
              	
			when waitMemAck0 =>
                -- Wait one cycle to the previous write order take effect
                if flag='0' then
                    if mem_fullReciveBuffer='0' then		
                        regReadCmdRqt(25 downto 0) := std_logic_vector(addrPlusOne); -- Note Gen index + sample addr
                        -- Write command in the mem buffer
                        mem_writeReciveBuffer <= '1';
                        flag :=not flag;
						state := checkGeneratorRqt;
						if turnGen=NUM_GENS-1 then -- Until max notes
							turnGen := (others=>'0');
							if turnTrack=1 then
								turnTrack :=(others=>'0');
							else
								turnTrack :=turnTrack+1;
							end if;
						else
							turnGen := turnGen+1;
						end if;                
                    end if;
			   else
			    flag := not flag;
			   end if;
			   
        end case;
        
    end if; --rst_n='0'/rising_edge(clk) 
end process;
  
end Behavioral;