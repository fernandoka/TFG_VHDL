---------------------------------------------------------------------
--
--  Fichero:
--    visioFlash.vhd  15/11/2019
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Visualiza sobre los displays el contenido de la Flash
--
--  Retocado por Fernando Candelario para el desarrollo del TFG
--  Versión: 0.4
--  Notas de diseño:
--    - La conexión de sck se hace implícitamente al usar la primitiva
--      STARTUPE2, por eso no está declarada en la entity ni aparece
--      en el fichero ucf/xdc el pin E9
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity visioFlash is
  port
  (
    rst_n  : in  std_logic;
    clk    : in  std_logic;
    btnc   : in  std_logic;
    btnu   : in  std_logic;
    sw     :  in std_logic_vector (15 downto 0);
    led_o  : out std_logic_vector(11 downto 0);
    an_n   : out std_logic_vector (7 downto 0);
    segs_n : out std_logic_vector (7 downto 0);
    cs_n   : out std_logic;   -- selección de esclavo
    io0    : inout std_logic;    
    io1    : inout  std_logic;   
    io2    : inout  std_logic;
    io3    : inout  std_logic   
--    wp     : in  std_logic;
--    hld    : in  std_logic
  );
end visioFlash;

---------------------------------------------------------------------

Library UNISIM;
use UNISIM.vcomponents.all;

use work.common.all;

architecture syn of visioFlash is

  constant FREQ : natural := 100_000;  -- frecuencia de operacion en KHz

  -- Comandos de la Flash    
  constant REMS_CMD     : std_logic_vector (7 downto 0) := X"90";
  constant READ_CMD     : std_logic_vector (7 downto 0) := X"03";
  constant DUALREAD_CMD : std_logic_vector (7 downto 0) := X"3B";
  constant QUADREAD_CMD : std_logic_vector (7 downto 0) := X"6B";

  signal btncSync, btncDeb, btncRise : std_logic;
  signal btnuSync, btnuDeb, btnuRise : std_logic;
  
  signal sck, contMode : std_logic;
  
  signal spiDataOutRdy : std_logic;
  signal spiDataIn : std_logic_vector (7 downto 0);
  signal spiDataOut : std_logic_vector (31 downto 0);
  
  signal manufacturerID, deviceID : std_logic_vector (7 downto 0);

  signal addr : std_logic_vector (23 downto 0);

  signal bin : std_logic_vector (31 downto 0);
  
  signal spiDataInRdy : std_logic;
  signal spiBusy, quadMode : std_logic;
  signal CommandPlusAddr : std_logic_vector (31 downto 0);

begin
    
  addr <= "000000" & sw & "00";
  
  readSynchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnc, xSync => btncSync );

  readDebouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btncSync, xDeb => btncDeb );
    
  readDebouncerEdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btncDeb, xFall => open, xRise => btncRise );


  readSynchronizer2 : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnu, xSync => btnuSync );

  readDebouncer2 : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnuSync, xDeb => btnuDeb );
    
  readDebouncerEdgeDetector2 : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnuDeb, xFall => open, xRise => btnuRise );



  -- Puede llegar a funcionar hasta 15_000_000 baudios
  spiInterface : spiMaster_Quad
    generic map( FREQ => FREQ, BAUDRATE => 10_000_000) 
    port map( 
          rst_n    => rst_n,
          clk      => clk,
          contMode => contMode,
          quadMode => quadMode,
          dataOutRdy  => spiDataOutRdy,
          dataIn   => spiDataIn,
          dataOut  => spiDataOut,
          dataInRdy_n => spiDataInRdy,
          busy       => spiBusy,
          
          -- SPI side
          sck      => sck,
          ss_n     => cs_n,
          io0      => io0,   
          io1_in      => io1,
          io2_in      => io2,
          io3_in      => io3
    );
   -- STARTUPE2: STARTUP Block
   --            Artix-7
   -- Xilinx HDL Language Template, version 14.7
   STARTUPE2_inst : STARTUPE2
   generic map (
      PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
      SIM_CCLK_FREQ => 0.0  -- Set the Configuration Clock Frequency(ns) for simulation.
   )
   port map (
      CFGCLK => open,       -- 1-bit output: Configuration main clock output
      CFGMCLK => open,     -- 1-bit output: Configuration internal oscillator clock output
      EOS => open,             -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ => open,           -- 1-bit output: PROGRAM request to fabric output
      CLK => '0',             -- 1-bit input: User start-up clock input
      GSR => '0',             -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS => '0',             -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0', -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK => '0',           -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO => sck,   -- 1-bit input: User CCLK input
      USRCCLKTS => '0', -- 1-bit input: User CCLK 3-state enable input 
      USRDONEO => '1',   -- 1-bit input: User DONE pin output control
      USRDONETS => '1'  -- 1-bit input: User DONE 3-state enable output (parece que podría ser 0)
   );
   
   

CommandPlusAddr <= QUADREAD_CMD & addr when quadMode='1' else READ_CMD & addr;

-- Debug
led_o(1 downto 0) <= '0' & quadMode;
   
 fsmd :
   process (rst_n, clk,spiDataInRdy,btncRise)
      type states is ( 
            waiting, sendDummy, waitingCommandRecive, sendReadCommand, readByte0, readByte1, readByte2, readByte3
      );
      variable state : states; 
   begin

-- Debug    
    led_o(10 downto 2) <= (others=>'0');
    led_o(11) <=contMode;
    
    if state=waiting then
        led_o(2) <= '1';
    end if;

    if state=sendDummy then
        led_o(3) <= '1';
    end if;   
   
   if state=waitingCommandRecive then
        led_o(4) <= '1';
    end if;
   
   if state=sendReadCommand then
        led_o(5) <= '1';
    end if;

   if state=readByte0 then
        led_o(6) <= '1';
    end if;

   if state=readByte1 then
        led_o(7) <= '1';
    end if;
    
   if state=readByte2 then
        led_o(8) <= '1';
   end if;
    
    if state=readByte3 then
        led_o(9) <= '1';
    end if;
--
    
    
    
     if rst_n='0' then
       spiDataOutRdy <= '0';
       spiDataOut <= (others => '0');
       contMode <= '1';
       quadMode <= '0';
       state    := waiting;
     elsif rising_edge(clk) then
       spiDataOutRdy <= '0';  -- asegura que spiDataRdy esté solo un ciclo activo
         case state is
           when waiting =>
             
             if btnuRise='1' then
                quadMode <= not quadMode;
             end if;
             
             if( btncRise='1' and spiBusy='0' ) then
               state := sendDummy;
             end if;
            
            -- La primera transferencia tras la carga siempre falla, o bien se hace un reset o se manda un comando inofensivo
            when sendDummy => 
                spiDataOutRdy  <= '1';
                spiDataOut <= REMS_CMD & X"000000";
                contMode <= '0';
                state := waitingCommandRecive;  
                
          when waitingCommandRecive =>
              if spiBusy='1' then
                  state := sendReadCommand;
              end if;
                        
          when sendReadCommand =>
             if spiBusy='0' then
                 spiDataOutRdy  <= '1';
                 contMode <= '1';
                 spiDataOut <= CommandPlusAddr; -- Inst = QUADREAD_CMD & ini Addr
                 state := readByte0;
             end if;
             
           when readByte0 =>
             if spiDataInRdy='0' then
                 state := readByte1;
                 bin(7 downto 0) <= spiDataIn;
             end if;      
                   
           when readByte1 =>
             if spiDataInRdy='0' then
                 state := readByte2;
                 bin(15 downto 8) <= spiDataIn;              
             end if;
             
           when readByte2 =>
             if spiDataInRdy='0' then
                 state :=  readByte3;
                 bin(23 downto 16) <= spiDataIn;
             end if;
             
          when readByte3 =>
               if spiDataInRdy='0' then
                   contMode <= '0';
                   state := waiting;
                   bin(31 downto 24) <= spiDataIn;
               end if;
  
                
          end case; 
       end if;
   end process;  
  
  
  displayInterface : segsDisplayInterface
    generic map ( FREQ => FREQ, COLS => 8, DITS => 8, PPOS => 0 )
    port map ( rst_n => rst_n, clk => clk, bin => bin, an_n => an_n, segs_n => segs_n );   
  
end syn;
