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
-- Revision 0.1
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

entity MidiParser.vhd is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
		ce							:	in	std_logic;
		

		-- Debug
		statesOut_ODBD				:	out std_logic_vector(2 downto 0);

        
        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(129 downto 0);
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(26 downto 0); 
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  MidiParser.vhd  :   entity  is  "true";
    
end MidiParser.vhd;

use work.my_common.all;

architecture Behavioral of MidiParser.vhd is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
	type    byteAddr_t  is array(0 to 1) of std_logic_vector(26 downto 0); 
	type    byteData_t  is array( 0 to 1 ) of std_logic_vector(7 downto 0);
	type    memAddr_t  is array( 0 to 1 ) of std_logic_vector(22 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For ODBD
    signal  ODBD_readRqt, ODBD_readyVal 	:   std_logic;
	signal	divisionVal						:	std_logic_vector(15 downto 0); -- Input in ODBD component, used as output signal in Read Header Component
	signal	ODBD_Val						:	std_logic_vector(23 downto 0);
	signal	mem_ODBD_addr					:	std_logic_vector(24 downto 0);
	
	-- For ByteProvider components
	signal	BP_addr				:	byteAddr_t;
	signal	BP_data				:	byteData_t;
	signal	BP_byteRqt, BP_ack	:	std_logic_vector(1 downto 0);
	
	-- For manage the mem CMDs
	signal	memAckSend, memAckResponse, memSamplesSendRqt	:	std_logic_vector(1 downto 0);
	signal	mem_byteP_addrOut								:	memAddr_t;
	
begin

----------------------------------------------------------------------------------
-- COMPONENTS
--		MidiController
--      Byte Provider components
--		OneDividedByDivision component
--		Read Header Component
--		Read Track Components
----------------------------------------------------------------------------------  

-- MidiController


-- Byte Provider components
ByteProvider_0 : ByteProvider
  Port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr(0),			
        byteRqt =>BP_byteRqt(0),  
        byteAck => BP_ack(0),            
        nextByte =>BP_data(0),
      
        -- Mem side
		samples_in       	=>	mem_CmdReadResponse(127 downto 0),
        memAckSend       	=>	memAckSend(0),
        memAckResponse   	=>	memAckResponse(0),
        addr_out         	=>	mem_byteP_addrOut(0)    
		memSamplesSendRqt	=>	memSamplesSendRqt(0)

	);


ByteProvider_1 : ByteProvider
  Port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr(1),			
        byteRqt =>BP_byteRqt(1),  
        byteAck => BP_ack(1),            
        nextByte =>BP_data(1),
      
        -- Mem arbitrator side
		samples_in       	=>	mem_CmdReadResponse(127 downto 0),
        memAckSend       	=>	memAckSend(1),
        memAckResponse   	=>	memAckResponse(1),
        addr_out         	=>	mem_byteP_addrOut(1)    
		memSamplesSendRqt	=>	memSamplesSendRqt(1)

  );

-- OneDividedByDivision component
my_ODBD_Provider : OneDividedByDivision_Provider
  generic map(START_ADDR=>299*4) -- 32 bits Address of the first value of OneDividedByDivision constants stored in DDR memory 
  port map( 
        rst_n           		=> rst_n,
        clk             		=> clk,
		readRqt					=> ODBD_readRqt,
		division				=> divisionVal,
		readyValue				=> ODBD_readyVal,
		OneDividedByDivision	=> ODBD_Val,
		
		--Debug
		statesOut       		=> statesOut_ODBD,
		 
		-- Mem arbitrator side
		dataIn       			=>	mem_CmdReadResponse(31 downto 0),
		memAckSend      		=>	memAckSend(2),
		memAckResponse			=>	memAckResponse(2),
		addr_out        		=>	mem_ODBD_addr,    
		memConstantSendRq		=>	memSamplesSendRqt(2)

  );

-- Read Header Component
my_ReadHeaderChunk : ReadHeaderChunk
  generic map(START_ADDR=>0)
  Port map( 
        rst_n => rst_n,
        clk => clk,
		readRqt => startHeaderRead,			
        finishRead => readFinish,  
        headerOk => headerOKe,
        division => divisionVal,
        track0AddrStart =>track0AddrStartVal,
        track1AddrStart => track1AddrStartVal,
        
        --Debug
        regAuxOut =>regAux,
        cntrOut =>cntrOut,
        statesOut =>statesOut,
        
        -- Byte provider side
        nextByte =>BP_data(0),
        byteAck =>BP_ack(0),
        byteAddr =>BP_addr,
        byteRqt =>BP_byteRqt
  );










----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(rst_n,clk,fsmsCen,mem_emptyBuffer)
begin
    if rst_n='0' then
		memAckResponse <=(others=>'0');
		mem_readResponseBuffer <='0';
		
    elsif rising_edge(clk) then
        memAckResponse <=(others=>'0');
		mem_readResponseBuffer <='0';
		
		 if mem_emptyBuffer='0' then
			mem_readResponseBuffer <='1';
			
			if mem_CmdReadResponse(129 downto 128))="11" then
				memAckResponse(2) <='1';
			else
				memAckResponse(to_integer( unsigned(mem_CmdReadResponse(129 downto 128)) )) <='1';
			end if;
			
		 end if;
		 
    end if;
end process;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,fsmsCen,memSamplesSendRqt,mem_fullBuffer)
    type states is ( checkGeneratorRqt);
    
    variable state      	:   states;
    variable turnCntr   	:   unsigned(1 downto 0);
    variable regReadCmdRqt 	:   std_logic_vector(26 downto 0);
    
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
			
            when checkGeneratorRqt =>
                 if ce='1' and memSamplesSendRqt(to_integer(turnCntr))='1' then
                        -- Write command in the mem buffer
                        mem_writeReciveBuffer <= '1';
						-- Send ack to note gen
                        memAckSend(to_integer(turnCntr)) <='1';
						state := waitMemAck0;
						
						-- Build cmd
						regReadCmdRqt := std_logic_vector(turnCntr) & mem_byteP_addrOut(to_integer(turnCntr)) & "00"; -- provider index + provider addr
						if turn=2 then
							regReadCmdRqt := "11" & mem_ODBD_addr; -- ODBD index + ODBD addr
                        end if;
						
                 else
                    if turnCntr=2 then -- Until max providers
                        turnCntr := (others=>'0');
                    else
                        turnCntr := turnCntr+1;
                    end if;     
                 end if;   
            

        end case;
        
    end if;
end process;
  
end Behavioral;