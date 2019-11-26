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
    
    constant clkPeriod : time := 10 ns;   -- Periodo del reloj (100 MHz)

  constant FREQ : natural := 100_000;  -- frecuencia de operacion en KHz

  -- Comandos de la Flash    
  constant REMS_CMD     : std_logic_vector (7 downto 0) := X"90";
  constant READ_CMD     : std_logic_vector (7 downto 0) := X"03";
  constant DUALREAD_CMD : std_logic_vector (7 downto 0) := X"3B";
  constant QUADREAD_CMD : std_logic_vector (7 downto 0) := X"6B";

  signal sck, contMode,cs_n : std_logic;
  signal io0,io1,io2,io3 : std_logic;

  signal spiDataOutRdy, spiDataInRdy, btncRise,sendFlag : std_logic; 
  signal spiEarlyBusy : std_logic;
  signal spiDataIn : std_logic_vector (7 downto 0);
  signal spiDataOut : std_logic_vector (31 downto 0);
    signal addr : std_logic_vector (23 downto 0);
    
    
    --Debug
    signal leds : std_logic_vector(8 downto 0);
    signal bitPosVal  :  std_logic_vector(4 downto 0);
    
    -- Señales 
    signal clk     : std_logic := '1';      
    signal rst_n   : std_logic := '0';

   type states is ( 
     waiting, sendReadCommand, readByte0, readByte1, readByte2, readByte3
   );
   
  signal state : states;

begin

btncRise <='1';
addr <= (others=>'0');

 fsmd :
 process (rst_n, clk,state,spiDataInRdy,btncRise)

 begin 
   if rst_n='0' then
     spiDataOutRdy <= '0';
     spiDataOut <= (others => '0');
     contMode   <= '0';
     state      <= waiting;
   elsif rising_edge(clk) then
     spiDataOutRdy <= '0';  -- asegura que spiDataRdy esté solo un ciclo activo
       case state is
         when waiting =>
           if( btncRise='1' ) then
             state  <= sendReadCommand;
           end if;
--          when sendDummy => -- La primera transferencia tras la carga siempre falla, o bien se hace un reset o se manda un comando inofensivo
--              spiDataOutRdy  <= '1';
--              spiDataOut <= REMS_CMD & X"000000";
--              contMode <= '0';
--              state := sendReadCommand;            
        when sendReadCommand =>
           spiDataOutRdy  <= '1';
           spiDataOut <= QUADREAD_CMD & addr; -- Inst = QUADREAD_CMD & ini Addr
           contMode <= '1';
           state <=  readByte0;
         when readByte0 =>
           if spiDataInRdy='0' then
               contMode <= '1';            
               state <= readByte1;
           end if;            
         when readByte1 =>
           if spiDataInRdy='0' then
               contMode <= '1';            
               state <=  readByte2;              
           end if;
         when readByte2 =>
           if spiDataInRdy='0' then
               contMode <= '0';            
               state <=  readByte3;
           end if;                
         when readByte3 =>
           if spiDataInRdy='0' then
               state <= waiting;
           end if;
       end case; 
     end if;
 end process;  
 
  -- Puede llegar a funcionar hasta 15_000_000 baudios
  spiInterface : spiMaster_Quad
    generic map( FREQ => FREQ, BAUDRATE => 10_000_000) 
    port map( 
          rst_n    => rst_n,
          clk      => clk,
          contMode => contMode,
          dataOutRdy  => spiDataOutRdy,
          dataIn   => spiDataIn,
          dataOut  => spiDataOut,
          dataInRdy_n => spiDataInRdy,
          
          --debug
          leds     =>leds,
          bitPosVal =>bitPosVal,
          sendFlagVal  => sendFlag,

          -- SPI side
          sck      => sck,
          ss_n     => cs_n,
          io0      => io0,   
          io1_in   => io1,
          io2_in   => io2,
          io3_in   => io3
    );

    clkGen:
        clk <= not clk after clkPeriod/2;
    
    rstGen :
        rst_n <= 
        '1' after (50 us + 5 ns), 
        '0' after (50000 ms);
        

end sim3;
