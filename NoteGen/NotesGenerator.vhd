----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
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
-- Revision 1.2
-- Additional Comments:
--		Not completly generic component, the pipelined sum and the NotesGenerators 
--		have to be done by hand
-- 
--		NUM_GENS constant must be a power of 2
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
  Generic (NUM_GENS	:	in	natural);
  Port ( 
        rst_n           					:   in  std_logic;
        clk             					:   in  std_logic;
        notes_on        					:   in  std_logic_vector(NUM_GENS-1 downto 0);
        working								:	out	std_logic_vector(NUM_GENS-1 downto 0);
				
		--Note params		
		startAddr_In             			: in std_logic_vector(25 downto 0);
		sustainStartOffsetAddr_In			: in std_logic_vector(25 downto 0);
		sustainEndOffsetAddr_In     		: in std_logic_vector(25 downto 0);
		maxSamples_In               		: in std_logic_vector(25 downto 0);
		stepVal_In                  		: in std_logic_vector(63 downto 0);
		sustainStepStart_In         		: in std_logic_vector(63 downto 0);
		sustainStepEnd_In           		: in std_logic_vector(63 downto 0);
				
		--IIS side		
        sampleRqt       					:   in  std_logic;
        sampleOut       					:   out std_logic_vector(15 downto 0);
        
        -- Notes Gen side
		mem_CmdReadResponse					:	in	std_logic_vector(15 downto 0); 
		memAckResponse                      :	in	std_logic_vector(NUM_GENS-1 downto 0);
		memAckSend							:	in	std_logic_vector(NUM_GENS-1 downto 0);
		memSamplesSendRqt   				:	out	std_logic_vector(NUM_GENS-1 downto 0);
		notesGen_addrOut					:	out	std_logic_vector(26*(NUM_GENS-1)+25 downto 0)
		
  );
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  NotesGenerator  :   entity  is  "true";
end NotesGenerator;

use work.my_common.all;

architecture Behavioral of NotesGenerator is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
    -- This generate more signals that the necessary ones
	-- Trust in the syntesis tool to avoid the mapping of unnecesary signals
	type    signalsPerLevel  is array( 0 to NUM_GENS-1 ) of std_logic_vector(15 downto 0); 
	type    samples  is array( 0 to log2(NUM_GENS) ) of signalsPerLevel;
	

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For sum
    signal  notesGen_samplesOut :   samples;
		
begin

----------------------------------------------------------------------------------
-- PIPELINED SUM
--      Manage the sums of all notes, is organized as a balanced tree
---------------------------------------------------------------------------------- 
genTreeLevels:
for i in 0 to log2(NUM_GENS)-1 generate
	genFixedSumsPerTreeLevel:
	for j in 0 to ( (NUM_GENS/2**(i+1)) - 1) generate
		sum: MyFiexedSum
		generic map(WL=>16)
		port map( rst_n =>rst_n, clk=>clk,a_in=>notesGen_samplesOut(i)(j*2),b_in=>notesGen_samplesOut(i)(j*2+1),c_out=>notesGen_samplesOut(i+1)(j));
	end generate;
end generate;

sampleOut <= notesGen_samplesOut(log2(NUM_GENS))(0);

----------------------------------------------------------------------------------
-- NOTES GENERATOR
--      Creation of the notes generators components
----------------------------------------------------------------------------------

genNotes:
for i in 0 to NUM_GENS-1 generate
	NoteGen: UniversalNoteGen
	  port map(
		-- Host side
		rst_n                   	=> rst_n,
		clk                     	=> clk,
		noteOnOff               	=> notes_on(i),
		sampleRqt    				=> sampleRqt, -- IIS new sample Rqt
		working						=> working(i),
		sample_out              	=> notesGen_samplesOut(0)(i),

		-- NoteParams               
		startAddr_In				=> startAddr_In				,
		sustainStartOffsetAddr_In	=> sustainStartOffsetAddr_In,
		sustainEndOffsetAddr_In    	=> sustainEndOffsetAddr_In  ,
		maxSamples_In				=> maxSamples_In			,
		stepVal_In					=> stepVal_In				,
		sustainStepStart_In			=> sustainStepStart_In		,
		sustainStepEnd_In			=> sustainStepEnd_In		,

		-- Mem side                 
		samples_in                  => mem_CmdReadResponse,    	
		memAckSend                 	=> memAckSend(i),     	
		memAckResponse		       	=> memAckResponse(i),      	
		addr_out                   	=> notesGen_addrOut(26*i+25 downto 26*i),     	
	    memSamplesSendRqt  		   	=> memSamplesSendRqt(i)
	  );

end generate;

  
end Behavioral;