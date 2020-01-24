----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: RamCntrl - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.2
-- Additional Comments:
--		In read mode, only the read buffers are used, in write mode only the write buffer is used.
--		
--		With Quick Read feature
--
--		-- For Midi parser component --
--		Format of inCmdReadBuffer_0	:	cmd(24 downto 0) = 4bytes addr to read,  
--									 	
--										cmd(26 downto 25) = "00" -> cmd from byteProvider_0
--									                   
--								    	cmd(26 downto 25) = "01" -> cmd from byteProvider_1
--					                                   
--										cmd(26 downto 25) = "11" -> cmd from OneDividedByDivisionProvider
--
--		-- For KeyboardCntrl --
--		Format of inCmdReadBuffer_1 :	cmd(25 downto 0) = sample addr to read 
--									 	
--										cmd(32 downto 26) = NoteGen index, the one which request a read
--
--
--		-- For Midi parser component --
--		Format of outRqtReadBuffer_0 :	If requestComponent is byteProvider_0 or byteProvider_1
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
--		-- For KeyboardCntrl --
--		Format of outRqtReadBuffer_1 :	cmd(15 downto 0) = sample addr to read 
--									 	
--										cmd(22 downto 16) = NoteGen index, the one which request a read
--
--
--		-- For SetupComponent and for BLstoreMidiFile --
--		Format of inCmdWriteBuffer :	cmd(15 downto 0) = 2 data bytes 
--									 	
--										cmd(41 downto 16) = NoteGen index, the one which request a read
--
--
--
--
--
----------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity RamCntrl is
   port (
      -- Common
      clk_200MHz_i				:	in    std_logic; -- 200 MHz system clock
      rst_n      				:	in    std_logic; -- active low system reset
      ui_clk_o    				:	out   std_logic;

      -- Ram Cntrl Interface
	  rdWr						:	in	std_logic; -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	:	in	std_logic_vector(26 downto 0); -- For midi parser component 
	  wrRqtReadBuffer_0     	:	in	std_logic; 
	  fullCmdReadBuffer_0		:	out	std_logic;
		
	  inCmdReadBuffer_1     	:	in	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
      wrRqtReadBuffer_1			:	in	std_logic;
	  fullCmdReadBuffer_1		:	out	std_logic;
	  
	  -- Buffers and signals to manage the read response commands
	  rdRqtReadBuffer_0			:	in	std_logic;
	  outCmdReadBuffer_0		:	out	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
	  emptyResponseRdBuffer_0	:	out	std_logic;
	  
	  rdRqtReadBuffer_1			:	in	std_logic;
	  outCmdReadBuffer_1		:	out	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
	  emptyResponseRdBuffer_1	:	out	std_logic;	  

	  -- Buffer and signals to manage the writes commands
	  inCmdWriteBuffer			:	in	std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
	  wrRqtWriteBuffer			:	in	std_logic;
	  fullCmdWriteBuffer		:	out	std_logic;
	  writeWorking				:	out	std_logic; -- High when the RamCntrl is executing some write command, low when no writes 
		
      -- DDR2 interface	
      ddr2_addr            		: 	out   std_logic_vector(12 downto 0);
      ddr2_ba              		: 	out   std_logic_vector(2 downto 0);
      ddr2_ras_n           		: 	out   std_logic;
      ddr2_cas_n           		: 	out   std_logic;
      ddr2_we_n            		: 	out   std_logic;
      ddr2_ck_p            		: 	out   std_logic_vector(0 downto 0);
      ddr2_ck_n            		: 	out   std_logic_vector(0 downto 0);
      ddr2_cke             		: 	out   std_logic_vector(0 downto 0);
      ddr2_cs_n            		: 	out   std_logic_vector(0 downto 0);
      ddr2_odt             		: 	out   std_logic_vector(0 downto 0);
      ddr2_dq              		: 	inout std_logic_vector(15 downto 0);
      ddr2_dm              		: 	out   std_logic_vector(1 downto 0);
      ddr2_dqs_p           		: 	inout std_logic_vector(1 downto 0);
      ddr2_dqs_n           		: 	inout std_logic_vector(1 downto 0)
   );	
   
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  RamCntrl  :   entity  is  "true";   
end RamCntrl;

architecture syn of RamCntrl is
------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------

	-- Mem
	signal	mem_ui_clk       			:	std_logic; 
	signal	mem_cen              		:	std_logic;
	signal	mem_rdn, mem_wrn            :	std_logic;
	signal	mem_addr             		:	std_logic_vector(25 downto 0);
	signal	mem_mem_ack          		:	std_logic;
	signal	mem_data_out, mem_data_in	:	std_logic_vector(15 downto 0);
	signal	mem_data_out_16B			:	std_logic_vector(127 downto 0);
	
	-- Fifos
	signal	fifoRqtRdData_0								:	std_logic_vector(26  downto 0);
	signal	fifoRqtRdData_1								:	std_logic_vector(32 downto 0);
	signal	inCmdResponseRdBuffer_0						:	std_logic_vector(129 downto 0)
	signal	inCmdResponseRdBuffer_1						:	std_logic_vector(22 downto 0);

	signal	rdRqtReadBuffer, emtyFifoRqtRd		 		:	std_logic_vector(1 downto 0);
	signal	wrResponseReadBuffer, fullResponseRdBuffer	:	std_logic_vector(1 downto 0);
	
	signal	CmdWrite									:	std_logic_vector(41 downto 0);
	signal	rdCmdWriteBuffer, emptyCmdWriteBuffer		:	std_logic;							

begin


ui_clk_o <= mem_ui_clk;
----------------------------------------------------------------------------------
-- RAM2DDR COMPONENT, INTERFACE
----------------------------------------------------------------------------------

RAM: Ram2Ddr 
   port map(
      -- Common
      clk_200MHz_i         => clk_200MHz,
      rstn_i               => rst_n,
      ui_clk_o             => mem_ui_clk,
      ui_clk_sync_rst_o    => open,

      -- RAM interface
      ram_a                => mem_addr, 		-- Addres 
      ram_dq_i             => mem_data_in,  	-- Data to write
      ram_dq_o             => mem_data_out,  	-- Data to read(2B)
      ram_dq_o_128         => mem_data_out_16B, -- Data to read(16B) 
      ram_cen              => mem_cen, 			-- To start a transaction, active low
      ram_oen              => mem_rdn, 			-- Read from memory, active low
      ram_wen              => mem_wrn, 			-- Write in memory, active low
      ram_ack              => mem_ack,
      
	  -- Debug
	  leds				   => ledsDDR,

	  
      -- DDR2 interface
      ddr2_addr            => ddr2_addr,
      ddr2_ba              => ddr2_ba,
      ddr2_ras_n           => ddr2_ras_n,
      ddr2_cas_n           => ddr2_cas_n,
      ddr2_we_n            => ddr2_we_n,
      ddr2_ck_p            => ddr2_ck_p,
      ddr2_ck_n            => ddr2_ck_n,
      ddr2_cke             => ddr2_cke,
      ddr2_cs_n            => ddr2_cs_n,
      ddr2_dm              => ddr2_dm,
      ddr2_odt             => ddr2_odt,
      ddr2_dq              => ddr2_dq,
      ddr2_dqs_p           => ddr2_dqs_p,
      ddr2_dqs_n           => ddr2_dqs_n
   );

----------------------------------------------------------------------------------
-- FIFO COMPONENTS
---------------------------------------------------------------------------------- 

-- Buffers to manage the read request commands
Fifo_inCmdReadBuffer_0: my_fifo
  generic map(WIDTH =>27, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrRqtReadBuffer_0,
    dataIn  => inCmdReadBuffer_0,
    rdE     => rdRqtReadBuffer(0),
    dataOut => fifoRqtRdData_0,
    full    => fullCmdReadBuffer_0,
    empty   => emtyFifoRqtRd(0)
  );


Fifo_inCmdReadBuffer_1: my_fifo
  generic map(WIDTH =>33, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrRqtReadBuffer_1,
    dataIn  => inCmdReadBuffer_1,
    rdE     => rdRqtReadBuffer(1),
    dataOut => fifoRqtRdData_1,
    full    => fullCmdReadBuffer_1,
    empty   => emtyFifoRqtRd(1)
  );
  
  
-- Buffers to manage the read response commands
Fifo_outCmdReadBuffer_0: my_fifo
  generic map(WIDTH =>130, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrResponseReadBuffer(0),
    dataIn  => inCmdResponseRdBuffer_0,
    rdE     => rdRqtReadBuffer_0,
    dataOut => outCmdReadBuffer_0,
    full    => fullResponseRdBuffer(0),
    empty   => emptyResponseRdBuffer_0
  );


Fifo_outCmdReadBuffer_1: my_fifo
  generic map(WIDTH =>23, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrResponseReadBuffer(1),
    dataIn  => inCmdResponseRdBuffer_1,
    rdE     => rdRqtReadBuffer_1,
    dataOut => outCmdReadBuffer_1,
    full    => fullResponseRdBuffer(1),
    empty   => emptyResponseRdBuffer_1
  );
  
  
 -- Buffer to manage the writes commands
Fifo_inCmdWriteBuffer: my_fifo
  generic map(WIDTH =>42, DEPTH =>4)
  port map(
    rst_n   => rst_n,
    clk     => clk,
    wrE     => wrRqtWriteBuffer,
    dataIn  => inCmdWriteBuffer,
    rdE     => rdCmdWriteBuffer,
    dataOut => CmdWrite,
    full    => fullCmdWriteBuffer,
    empty   => emptyCmdWriteBuffer
  );



ram_access : 
process (rst_n,mem_ui_clk) 
	type states is (idle, readCmdWriteBuffer, readInCmdReadBuffer_0, reciveAckInCmdReadBuffer_0, 
	readInCmdReadBuffer_1, reciveAckInCmdReadBuffer_1, reciveWriteAck );
	variable states	:	states;
	
	-- turn=0 or turn=1 -> read commands from Keyboard
	-- turn=2 -> read commands from Midi parser
	variable	turn			:	natural range 0 to 2;
	variable	regAux			:	std_logic_vector(6 downto 0);
	variable	regAuxDecode	:	std_logic_vector(2 downto 0);
	variable	flagAck			:	std_logic; -- Used to wait until the correspondant outputbuffer is not full
	
	-- Quick read feature
	variable	reg128bitsCache	:	std_logic_vector(127 downto 0);
	variable	regLast128Addr	:	std_logic_vector(22 downto 0);
	variable	OneReadFlag		:	std_logic;
	
begin

	------------------
	-- MOORE OUTPUT --
	------------------
	mem_cen <='1';
	if state/=idle then
		mem_cen <='0';
	end if;

	if rst_n = '0' then
		mem_addr <=(others=>'0');
		mem_data_in <=(others=>'0');
		mem_rdn <='1';
		mem_wdn <='1';
		rdCmdWriteBuffer <='0';
		rdRqtReadBuffer <=(others=>'0');
		wrResponseReadBuffer <=(others=>'0');
		regAux := (others=>'0');
		reg128bitsCache :=(others=>'0');
		regLast128Addr :=(others=>'0');
		flagAck :='0';
		OneReadFlag := '0';
		turn := 0;
		state := idle;
		
	elsif rising_edge(mem_ui_clk) then
		mem_rdn <='1';
		mem_wdn <='1';
		rdCmdWriteBuffer <='0';
		rdRqtReadBuffer <=(others=>'0');
		wrResponseReadBuffer <=(others=>'0');

		case state is
			when => idle
				-- Write ram
				if rdWr='0' and emptyCmdWriteBuffer='0' then
					state := readCmdWriteBuffer;
				-- Read ram
				elsif rdWr='1' and (emtyFifoRqtRd(0)='0' or emtyFifoRqtRd(1)='0') then
					if turn < 2 then
						-- Priority of KeyboardCntrl component
						if emtyFifoRqtRd(1)='1' then
							turn := turn+1
							state := readInCmdReadBuffer_1;
						else
							turn := 2; -- Check buffer of Midi parser
						end if;
					else
						turn := 0;
						state := readInCmdReadBuffer_0;
					end if;
				end if;
				
			-----------------------------
			-- States to perform write --
			-----------------------------
			when => readCmdWriteBuffer
				mem_addr <= CmdWrite(41 downto 16);
				mem_data_in <= CmdWrite(15 downto 0);
				-- Write order to mem
				mem_wrn <='0';
				-- Read order to fifo, consume a mem command
				rdCmdWriteBuffer <='1';
				state := reciveWriteAck;
				
			when => reciveWriteAck
				if mem_ack='1' then
					state := idle;
				end if;
			
			----------------------------
			-- States to perform read --
			----------------------------
			-- READ IN CMD READ BUFFER 0
			when => readInCmdReadBuffer_0
				-- Read order to fifo, consume a mem command
				rdRqtReadBuffer(0) <='1';
				
				-- QucikRead
				if OneReadFlagfifoRqtRdData_0(24 downto 2)=regLast128Addr then
					-- Write command to fifo
					wrResponseReadBuffer(0)<='1';
					state := idle;
					if regAux(1 downto 0)/="11" then
						inCmdResponseRdBuffer_0 <= fifoRqtRdData_0(26 downto 25) & reg128bitsCache;
					-- OneByDivisionValue
					else
						inCmdResponseRdBuffer_0 <=(others=>'0');
						inCmdResponseRdBuffer_0(129 downto 128) <= fifoRqtRdData_0(26 downto 25);
						-- Decode addr
						case fifoRqtRdData_0(1 downto 0) is
							when "00" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= reg128bitsCache(31 downto 0);
							when "01" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= reg128bitsCache(63 downto 32);
							when "10" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= reg128bitsCache(95 downto 64);
							when "11" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= reg128bitsCache(127 downto 96);
						end case;
				-- Order read
				else
					OneReadFlag := '1';
					regLast128Addr := fifoRqtRdData_0(24 downto 2); -- Update last addr
					
					mem_addr <= fifoRqtRdData_0(24 downto 2);
					regAux(1 downto 0) := fifoRqtRdData_0(26 downto 25);
					regAuxDecode(1 downto 0) := fifoRqtRdData_0(1 downto 0);
					-- Read order to mem
					mem_rdn <='0';
					
					flagAck := '0';-- Set flagAck value
					state := reciveAckInCmdReadBuffer_0;
				end if;
				
			when => reciveAckInCmdReadBuffer_0
				if mem_ack='1' then
					flagAck :='1';
				end if;

				-- Check if the buffer it's not full
				if mem_ack='1' then
					state := idle;
					-- Write command to fifo
					wrResponseReadBuffer(0)<='1'; 
					reg128bitsCache := mem_data_out_16B;-- Update cache
					if regAux(1 downto 0)/="11" then
						inCmdResponseRdBuffer_0 <= regAux(1 downto 0) & mem_data_out_16B;
					-- OneByDivisionValue
					else
						inCmdResponseRdBuffer_0<=(others=>'0');
						inCmdResponseRdBuffer_0(129 downto 128) <= regAux(1 downto 0);
						-- Decode addr
						case regAuxDecode(1 downto 0) is
							when "00" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= mem_data_out_16B(31 downto 0);
							when "01" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= mem_data_out_16B(63 downto 32);
							when "10" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= mem_data_out_16B(95 downto 64);
							when "11" =>
								inCmdResponseRdBuffer_0(31 downto 0) <= mem_data_out_16B(127 downto 96);
						end case;
					end if;
				end if;-- mem_ack='1'
				
			-- READ IN CMD READ BUFFER 1
			when => readInCmdReadBuffer_1
				-- Read order to fifo, consume a mem command
				rdRqtReadBuffer(1) <='1';
				
				-- QucikRead
				if OneReadFlag='1' and fifoRqtRdData_0(25 downto 3)=regLast128Addr then
					state := idle;
					-- Write command to fifo
					wrResponseReadBuffer(1)<='1';
					inCmdResponseRdBuffer_1(22 downto 16) <= fifoRqtRdData_1(32 downto 26);
					case fifoRqtRdData_0(2 downto 0) is
					   when "000" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(15 downto 0);
		   
					   when "001" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(31 downto 16);
							 
					   when "010" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(47 downto 32);
		   
					   when "011" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(63 downto 48);
		   
					   when "100" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(79 downto 64);
							 
					   when "101" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(95 downto 80);
							 
					   when "110" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(111 downto 96);
							 
					   when "111" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= reg128bitsCache(127 downto 112);						
					end case;
					
				-- Order read
				else
					OneReadFlag := '1';
					regLast128Addr := fifoRqtRdData_1(25 downto 3); -- Update last addr
					
					mem_addr <= fifoRqtRdData_1(25 downto 3);
					regAux := fifoRqtRdData_1(32 downto 26); -- Save note gen index
					regAuxDecode := fifoRqtRdData_1(2 downto 0)
					-- Read order to mem
					mem_rdn <='0';
	
					flagAck :='0'; -- Set flagAck value
					state := reciveAckInCmdReadBuffer_1;				
				end if;

			
			when => reciveAckInCmdReadBuffer_1
				if mem_ack='1' then
					flagAck :='1';
				end if;

				-- Check if the buffer it's not full
				if fullResponseRdBuffer(1)='0' and (mem_ack='1' or flagAck ='1') then
					state := idle;
					reg128bitsCache := mem_data_out_16B; -- Update cache
					-- Write command to fifo
					wrResponseReadBuffer(1)<='1';
					inCmdResponseRdBuffer_1(22 downto 16) <= regAux;
					case regAuxDecode is
					   when "000" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(15 downto 0);
		   
					   when "001" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(31 downto 16);
							 
					   when "010" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(47 downto 32);
		   
					   when "011" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(63 downto 48);
		   
					   when "100" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(79 downto 64);
							 
					   when "101" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(95 downto 80);
							 
					   when "110" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(111 downto 96);
							 
					   when "111" => 
							 inCmdResponseRdBuffer_1(15 downto 0) <= mem_data_out_16B(127 downto 112);						
					end case;
				end if;-- mem_ack='1'

			
		end case;
		
		
	end if; -- rst/rising_edge
end process;

end syn;
