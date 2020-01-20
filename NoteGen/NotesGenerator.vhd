----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: NotesGenerator - Behavioral
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
--		Not completly generic component, the pipelined sum and the NotesGenerators 
--		have to be done by hand
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

entity NotesGenerator is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
        notes_on        			:   in  std_logic_vector(31 downto 0);
        
		--Note params
		startAddr_In             	: in std_logic_vector(25 downto 0);
		sustainStartOffsetAddr_In	: in std_logic_vector(25 downto 0);
		sustainEndOffsetAddr_In     : in std_logic_vector(25 downto 0);
		maxSamples_In               : in std_logic_vector(25 downto 0);
		stepVal_In                  : in std_logic_vector(63 downto 0);
		sustainStepStart_In         : in std_logic_vector(63 downto 0);
		sustainStepEnd_In           : in std_logic_vector(63 downto 0);
		
		--IIS side
        sampleRqt       			:   in  std_logic;
        sampleOut       			:   out std_logic_vector(15 downto 0);
        
        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(15+4 downto 0); -- mem_CmdReadResponse(19 downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(25+4 downto 0); -- mem_CmdReadRequest(29 downto 26)= note gen index, mem_CmdReadRequest(15 downto 0) = requested sample
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  NotesGenerator  :   entity  is  "true";
    
end NotesGenerator;

use work.my_common.all;

architecture Behavioral of NotesGenerator is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
    type    samplesOut  is array(0 to NUM_NOTES-1) of std_logic_vector(WL-1 downto 0);
    type    addrOut  is array(0 to NUM_NOTES-1) of std_logic_vector(25 downto 0);
    type    sumStage0   is array( 0 to (NUM_NOTES/2)-1 ) of std_logic_vector(WL-1 downto 0);
    type    sumStage1   is array( 0 to (NUM_NOTES/4)-1 ) of std_logic_vector(WL-1 downto 0);
    type    sumStage2   is array( 0 to (NUM_NOTES/8)-1 ) of std_logic_vector(WL-1 downto 0);
    type    sumStage3   is array( 0 to (NUM_NOTES/16)-1 ) of std_logic_vector(WL-1 downto 0);
    type    sumStage4   is array( 0 to 2) of std_logic_vector(WL-1 downto 0);

	
    type    iniData  is array(0 to 59) of natural;
    type    freq is array(0 to 87) of real;
	type	offset_t is array(0 to 87) of natural;
	
----------------------------------------------------------------------------------
-- CONSTANTS DECLARATIONS
----------------------------------------------------------------------------------         

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- Registers
    signal  notesGen_samplesOut         :   samplesOut;
             
    signal  notesEnable                 :   std_logic_vector(NUM_NOTES-1 downto 0);
    signal  memSamplesSendRqt, muxMemAck   :   std_logic_vector(NUM_NOTES-1 downto 0);
    
    signal  notesGen_addrOut            :   addrOut;
        
    signal  sampleOutAux_S0             :   sumStage0;
    signal  sampleOutAux_S1             :   sumStage1;
    signal  sampleOutAux_S2             :   sumStage2;
    signal  sampleOutAux_S3             :   sumStage3;
    signal  sampleOutAux_S4             :   sumStage4;
    
    signal  sampleOutAux_S5, sampleOutAux_S6    :   std_logic_vector(WL-1 downto 0);

begin
             
NotesEnableGen:
for i in 0 to (NUM_NOTES-1) generate
    notesEnable(i) <= notes_on(i) and cen;
end generate;


----------------------------------------------------------------------------------
-- PIPELINED SUM
--      Manage the sums of all notes, is organized like a balanced tree
---------------------------------------------------------------------------------- 


--Level 0
genSumLevel0:
for i in 0 to (NUM_NOTES/2)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>notesGen_samplesOut(i*2),b_in=>notesGen_samplesOut(i*2+1),c_out=>sampleOutAux_S0(i));
end generate;

--Level 1
genSumLevel1:
for i in 0 to (NUM_NOTES/4)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S0(i*2),b_in=>sampleOutAux_S0(i*2+1),c_out=>sampleOutAux_S1(i));
end generate;

--Level 2
genSumLevel2:
for i in 0 to (NUM_NOTES/8)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S1(i*2),b_in=>sampleOutAux_S1(i*2+1),c_out=>sampleOutAux_S2(i));
end generate;

--Level 3
genSumLevel3:
for i in 0 to (NUM_NOTES/16)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S2(i*2),b_in=>sampleOutAux_S2(i*2+1),c_out=>sampleOutAux_S3(i));
end generate;

-- Level 4
genSumLevel4:
for i in 0 to 1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S3(i*2),b_in=>sampleOutAux_S3(i*2+1),c_out=>sampleOutAux_S4(i));
end generate;

sum_L4: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S3(4),b_in=>sampleOutAux_S2(10),c_out=>sampleOutAux_S4(2));

-- Level 5
sum_L5: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S4(0),b_in=>sampleOutAux_S4(1),c_out=>sampleOutAux_S5);

-- Level 6, final sum
sum_L6: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S5,b_in=>sampleOutAux_S4(2),c_out=>sampleOutAux_S6);


sampleOut <= sampleOutAux_S6;

----------------------------------------------------------------------------------
-- NOTES GENERATOR
--      Creation of the notes generators components,
--
----------------------------------------------------------------------------------

genNotes:
for i in 0 to (NUM_NOTES/3)-1 generate
	NoteGen: UniversalNoteGen
	  port map(
		-- Host side
		rst_n                   	=> rst_n,
		clk                     	=> clk,
		noteOnOff               	=> notes_on(i),
		sampleRqt    				=> (i),
		working						=> working(i),
		sample_out              	=> sample_out(i),

		-- NoteParams               
		startAddr_In				=> startAddr_In				,
		sustainStartOffsetAddr_In	=> sustainStartOffsetAddr_In,
		sustainEndOffsetAddr_In    	=> sustainEndOffsetAddr_In  ,
		maxSamples_In				=> maxSamples_In			,
		stepVal_In					=> stepVal_In				,
		sustainStepStart_In			=> sustainStepStart_In		,
		sustainStepEnd_In			=> sustainStepEnd_In		,

		-- Mem side                 
		samples_in                  => mem_CmdReadResponse(15 downto 0),    	
		memAckSend                 	=> memAckSend(i),     	
		memAckResponse		       	=> memAckResponse(i),      	
		addr_out                   	=> notesGen_addrOut(i),     	
	    memSamplesSendRqt  		   	=> memSamplesSendRqt(i)
	  );

end generate;


----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(rst_n,clk,mem_ack)
begin
    if rst_n='0' then
		memAckResponse <=(others=>'0');
		mem_readResponseBuffer <='0';
		
    elsif rising_edge(clk) then
        memAckResponse <=(others=>'0');
		mem_readResponseBuffer <='0';
		
		 if mem_emptyBuffer='0' then
			memAckResponse(to_integer(mem_CmdReadResponse(19 downto 16))) <='1';
			mem_readResponseBuffer <='1';
		 end if;           
    end if;
end process;
  
end Behavioral;

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,mem_ack)
    type states is ( checkGeneratorRqt, waitMemAck0);
    
    variable state      :   states;
    variable turnCntr   :   unsigned(4 downto 0);
    variable cntr       :   unsigned(1 downto 0);
    variable regReadCmdRqt :   std_logic_vector(25+4 downto 0);
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;

    if rst_n='0' then
       turnCntr := (others=>'0');
       state := checkGeneratorRqt;
       regReadCmdRqt := (others=>'0');
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0');
	   
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
		memAckSend <=(others=>'0'); -- Just one cycle
        
		case state is
			-- Two Cmd per read request
            when checkGeneratorRqt =>
                 if memSamplesSendRqt(to_integer(turnCntr))='1' then
                        regReadCmdRqt := std_logic_vector(turnCntr) & notesGen_addrOut(to_integer(turnCntr)); -- Note Gen index + addr
                        -- Send read command in the next cycle
                        mem_writeReciveBuffer <= '1';
						-- Send ack to note gen
                        memAckSend(to_integer(turnCntr)) <='1';
						state := waitMemAck0;
                 else
                    if turnCntr=NUM_NOTES-1 then
                        turnCntr := (others=>'0');
                    else
                        turnCntr := turnCntr+1;
                    end if;     
                 end if;   
            
			
			when waitMemAck0 =>
                if mem_fullBuffer='0' then		
					regReadCmdRqt(25 downto 0) := regReadCmdRqt(25 downto 0)+1; -- Note Gen index + addr
					-- Order read in the next cycle
					mem_writeReciveBuffer <= '1';
					state := waitMemAck0;
				end if;
			
			
            when waitMemAck1 =>
                if mem_fullBuffer='0' then
					if turnCntr=NUM_NOTES-1 then
                        turnCntr := (others=>'0');
                    else
                        turnCntr := turnCntr+1;
                    end if; 
				   state := checkGeneratorRqt;                
                end if;

        end case;
        
        
        
    end if;
end process;
  
end Behavioral;
