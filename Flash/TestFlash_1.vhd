----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.09.2019 22:57:05
-- Design Name: 
-- Module Name: IIS_InterfaceTest - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestFlash_1 is
--  Port ( );
end TestFlash_1;

use work.common.all;

architecture sim3 of TestFlash_1 is
    
    constant clkPeriod : time := 100 ns;   -- Periodo del reloj (100 MHz)

	constant FREQ : natural := 100_000;  -- frecuencia de operacion en KHz

	-- Comandos de la Flash    
	constant REMS_CMD     : std_logic_vector (7 downto 0) := X"90";
	constant READ_CMD     : std_logic_vector (7 downto 0) := X"03";
	constant DUALREAD_CMD : std_logic_vector (7 downto 0) := X"3B";
	constant QUADREAD_CMD : std_logic_vector (7 downto 0) := X"6B";

	signal btncSync, btncDeb, btncRise : std_logic;

	signal sck, contMode : std_logic;

	signal spiDataRdy, spiEarlyBusy : std_logic;
	signal spiDataIn : std_logic_vector (7 downto 0);
	signal spiDataOut : std_logic_vector (31 downto 0);

	signal manufacturerID, deviceID : std_logic_vector (7 downto 0);

	signal addr : std_logic_vector (23 downto 0);

    -- Señales 
    signal clk     : std_logic := '1';      
    signal rst_n   : std_logic := '0';

    
begin

  -- Puede llegar a funcionar hasta 15_000_000 baudios
  spiInterface : spiMaster_Quad
    generic map( FREQ => FREQ, BAUDRATE => 10_000_000) 
    port map( 
          rst_n    => rst_n,
          clk      => clk,
          contMode => contMode,
          dataRdy  => spiDataRdy,
          dataIn   => spiDataIn,
          dataOut  => spiDataOut,
          earlyBusy => spiDataRdy,
          
          -- SPI side
          sck      => sck,
          ss_n     => cs_n,
          io0      => io0,   
          io1_in   => io1,
          io2_in   => io2,
          io3_in   => io3
    );

        
    sampleToSend:
        spiDataOut <= REMS_CMD & X"000000";
    
	genDataRdy:
		spiDataRdy <=
		'1' after (60 us + 5 ns), 
        '0' after (10 ns);
	
	gencontMode:
		contMode <= '0';
		
    rstGen :
        rst_n <= 
        '1' after (50 us + 5 ns), 
        '0' after (50000 ms);
        
    

end sim3;
