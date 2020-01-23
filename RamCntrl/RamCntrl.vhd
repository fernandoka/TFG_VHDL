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
-- Revision 0.1
-- Additional Comments:
--		In read mode, only the read buffers are used, in write mode only the write buffer is used.
--
--		-- For Midi parser component --
--		Format of inCmdReadBuffer_0	:	cmd(24 downto 0) = 4bytes addr to read,  
--									 	
--										cmd(28 downto 27) = "00" -> cmd from byteProvider_0
--									
--								    	cmd(28 downto 27) = "01" -> cmd from byteProvider_1
--					                
--										cmd(28 downto 27) = "11" -> cmd from OneDividedByDivisionProvider
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
      clk_200MHz_i			:	in    std_logic; -- 200 MHz system clock
      rst_n      			:	in    std_logic; -- active low system reset
      ui_clk_o    			:	out   std_logic;

      -- Ram Cntrl Interface
	  rdWr					:	in	std_logic; -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     :	in	std_logic_vector(28 downto 0); -- For midi parser component 
      wrRqtReadBuffer_0     :	in	std_logic; 
	  inCmdReadBuffer_1     :	in	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
      wrRqtReadBuffer_1		:	in	std_logic;

	  -- Buffers and signals to manage the read response commands
	  outCmdReadBuffer_0	:	out	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
	  fullCmdReadBuffer_0	:	out	std_logic;
	  outCmdReadBuffer_1	:	out	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
	  fullCmdReadBuffer_1	:	out	std_logic;

	  -- Buffer and signals to manage the writes commands
	  inCmdWriteBuffer		:	in	std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
	  wrRqtWriteBuffer		:	in	std_logic;
	  fullCmdWriteBuffer	:	out	std_logic;
	  writeWorking			:	out	std_logic; -- High when the RamCntrl is executing some write command, low when no writes 
	  
      -- DDR2 interface
      ddr2_addr            	: 	out   std_logic_vector(12 downto 0);
      ddr2_ba              	: 	out   std_logic_vector(2 downto 0);
      ddr2_ras_n           	: 	out   std_logic;
      ddr2_cas_n           	: 	out   std_logic;
      ddr2_we_n            	: 	out   std_logic;
      ddr2_ck_p            	: 	out   std_logic_vector(0 downto 0);
      ddr2_ck_n            	: 	out   std_logic_vector(0 downto 0);
      ddr2_cke             	: 	out   std_logic_vector(0 downto 0);
      ddr2_cs_n            	: 	out   std_logic_vector(0 downto 0);
      ddr2_odt             	: 	out   std_logic_vector(0 downto 0);
      ddr2_dq              	: 	inout std_logic_vector(15 downto 0);
      ddr2_dm              	: 	out   std_logic_vector(1 downto 0);
      ddr2_dqs_p           	: 	inout std_logic_vector(1 downto 0);
      ddr2_dqs_n           	: 	inout std_logic_vector(1 downto 0)
   );
   
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  RamCntrl  :   entity  is  "true";   
end RamCntrl;

architecture syn of RamCntrl is


------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------

-- Mem
signal mem_ui_clk           : std_logic; 
signal cen                  : std_logic;
signal rd,wr                : std_logic;
signal addr                 : std_logic_vector(25 downto 0);
signal mem_ack              : std_logic;
signal data_out, data_in    : std_logic_vector(15 downto 0);

signal muxControlSignals    : std_logic_vector(1 downto 0); -- 0:Addr, 1:Cen, 2:

begin


ui_clk_o <= mem_ui_clk;

RAM: Ram2Ddr 
   port map(
      -- Common
      clk_200MHz_i         => clk_200MHz,
      rstn_i               => rst_n,
      ui_clk_o             => mem_ui_clk,
      ui_clk_sync_rst_o    => open,

      -- RAM interface
      ram_a                => addr, -- Addres 
      ram_dq_i             => data_in,  -- Data to write
      ram_dq_o             => data_out,  -- Data to read(2B)
      ram_dq_o_128         => data_out_16B, -- Data to read(16B) 
      ram_cen              => cen, -- To start a transaction, active low
      ram_oen              => rd, -- Read from memory, active low
      ram_wen              => wr, -- Write in memory, active low
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
  generic map(WIDTH =>29, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrRqtReadBuffer_0,
    dataIn  => inCmdReadBuffer_0,
    rdE     => rdRqtReadBuffer_0,
    dataOut => fifoRqtRdData(0),
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
    rdE     => rdRqtReadBuffer_1,
    dataOut => fifoRqtRdData(1),
    full    => fullCmdReadBuffer_1,
    empty   => emtyFifoRqtRd(1)
  );
  
  
-- Buffers to manage the read response commands
Fifo_outCmdReadBuffer_0: my_fifo
  generic map(WIDTH =>130, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrFifo,
    dataIn  => ,
    rdE     => ,
    dataOut => ,
    full    => ,
    empty   => ,
  );


Fifo_outCmdReadBuffer_1: my_fifo
  generic map(WIDTH =>23, DEPTH =>8)
  port map(
    rst_n   => rst_n,
    clk     => mem_ui_clk,
    wrE     => wrFifo,
    dataIn  => dataInFifo,
    rdE     => keyboard_ack,
    dataOut => cmdKeyboard,
    full    => fullFifo,
    empty   => emtyCmdBuffer
  );
  
  
 -- Buffers to manage the writes commands
Fifo_inCmdWriteBuffer: my_fifo
  generic map(WIDTH =>42, DEPTH =>4)
  port map(
    rst_n   => rst_n,
    clk     => clk,
    wrE     => wrRqtWriteBuffer,
    dataIn  => inCmdWriteBuffer,
    rdE     => fifoRqtWr,
    dataOut => fifoRqtWrData,
    full    => fullCmdWriteBuffer,
    empty   => emptyFifoRqtWr
  );



-------------------------------------------------------------------------
  ram_access : process (rst_n,mem_ui_clk) 
  begin
    if rst_n = '0' then
    elsif rising_edge(mem_ui_clk) then

    end if; -- rst/rising_edge
  end process;
   
end syn;
