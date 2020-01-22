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
--
----------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity RamCntrl is
   port (
      -- Common
      clk_200MHz_i			: in    std_logic; -- 200 MHz system clock
      rstn_i      			: in    std_logic; -- active low system reset
      ui_clk_o    			: out   std_logic;

      -- Ram Cntrl Interface
	  rdWr					:	in std_logic; -- RamCntrl mode, high read low write
      inCmdReadBuffer_0     :	in	std_logic_vector(26+1 downto 0); -- For midi parser component 
      wrRqtReadBuffer_0     :	in	std_logic; 
	  inCmdReadBuffer_1     :	in	std_logic_vector(25+4 downto 0); -- For KeyboardCntrl component
      wrRqtReadBuffer_1		:	in	std_logic;
	  inCmdWriteBuffer		:	in	std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
	  wrRqtWriteBuffer		:	in	std_logic;
	  
	  outCmdReadBuffer_0	:	out	std_logic_vector(15+5 downto 0);
	  fullCmdReadBuffer_0	:	out	std_logic;
	  outCmdReadBuffer_1	:	out	std_logic_vector(15+5 downto 0);
	  fullCmdReadBuffer_1	:	out	std_logic;
	  
      -- DDR2 interface
      ddr2_addr            : out   std_logic_vector(12 downto 0);
      ddr2_ba              : out   std_logic_vector(2 downto 0);
      ddr2_ras_n           : out   std_logic;
      ddr2_cas_n           : out   std_logic;
      ddr2_we_n            : out   std_logic;
      ddr2_ck_p            : out   std_logic_vector(0 downto 0);
      ddr2_ck_n            : out   std_logic_vector(0 downto 0);
      ddr2_cke             : out   std_logic_vector(0 downto 0);
      ddr2_cs_n            : out   std_logic_vector(0 downto 0);
      ddr2_odt             : out   std_logic_vector(0 downto 0);
      ddr2_dq              : inout std_logic_vector(15 downto 0);
      ddr2_dm              : out   std_logic_vector(1 downto 0);
      ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
      ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
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
signal ui_clk               : std_logic; 
signal cen                  : std_logic;
signal rd,wr                : std_logic;
signal addr                 : std_logic_vector(25 downto 0);
signal mem_ack                  : std_logic;
signal data_out, data_in    : std_logic_vector(15 downto 0);

signal muxControlSignals    : std_logic_vector(1 downto 0); -- 0:Addr, 1:Cen, 2:

begin

RAM: Ram2Ddr 
   port map(
      -- Common
      clk_200MHz_i         => clk_200MHz,
      rstn_i               => rst_n,
      ui_clk_o             => ui_clk,
      ui_clk_sync_rst_o    => open,

      -- RAM interface
      ram_a                => addr, -- Addres 
      ram_dq_i             => data_in,  -- Data to write
      ram_dq_o             => data_out,  -- Data to read
      ram_dq_o_128         => open,
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



-------------------------------------------------------------------------
  ram_access : process () 
  begin

    
    if mem_ui_rst = '1' then
    elsif rising_edge(mem_ui_clk) then

    end if; -- rst/rising_edge
  end process;
   
end syn;
