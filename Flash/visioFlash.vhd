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
    sw     :  in std_logic_vector (15 downto 0);
    an_n   : out std_logic_vector (7 downto 0);
    segs_n : out std_logic_vector (7 downto 0);
    cs_n   : out std_logic;   -- selección de esclavo
    io0    : inout std_logic;    
    io1    : in  std_logic;   
    io2    : in  std_logic;
    io3    : in  std_logic   
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
  
  signal sck, contMode : std_logic;
  
  signal spiDataRdy, spiEarlyBusy : std_logic;
  signal spiDataIn : std_logic_vector (7 downto 0);
  signal spiDataOut : std_logic_vector (31 downto 0);
  
  signal manufacturerID, deviceID : std_logic_vector (7 downto 0);

  signal addr : std_logic_vector (23 downto 0);

  signal bin : std_logic_vector (31 downto 0);
   
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
   
  fsmd :
  process (rst_n, clk)
    type states is ( 
      waiting, sendDummy, sendReadCommand, sendAddr0, sendAddr1, sendAddr2, startReading, readByte0, readByte1, readByte2, readByte3
    );
    variable state : states;
  begin 
    if rst_n='0' then
      spiDataRdy <= '0';
      spiDataOut <= (others => '0');
      bin        <= (others => '0');
      contMode   <= '0';
      state      := waiting;
    elsif rising_edge(clk) then
      spiDataRdy <= '0';  -- asegura que spiDataRdy esté solo un ciclo activo
      if spiEarlyBusy='0' then 
        case state is
          when waiting =>
            if( btncRise='1' ) then
              state  := sendDummy;
            end if;
          when sendDummy => -- La primera transferencia tras la carga siempre falla, o bien se hace un reset o se manda un comando inofensivo
              spiDataRdy  <= '1';
              spiDataOut <= REMS_CMD;
              contMode <= '0';
              state := sendReadCommand;            
          when sendReadCommand =>
            spiDataRdy  <= '1';
            spiDataOut <= READ_CMD;
            contMode <= '1';
            state := sendAddr0;
          when sendAddr0 =>
            spiDataRdy  <= '1';
            contMode <= '1';            
            spiDataOut <= addr(23 downto 16); 
            state := sendAddr1;
          when sendAddr1 =>
            spiDataRdy  <= '1';
            contMode <= '1';            
            spiDataOut <= addr(15 downto 8); 
            state := sendAddr2;
          when sendAddr2 =>
            spiDataRdy  <= '1';
            contMode <= '1';           
            spiDataOut <= addr(7 downto 0); 
            state := startReading;
          when startReading =>
            spiDataRdy  <= '1';
            contMode <= '1';            
            spiDataOut <= (others => '0'); 
            state := readByte0;
          when readByte0 =>
            spiDataRdy  <= '1';
            contMode <= '1';            
            bin(7 downto 0) <= spiDataIn;
            state := readByte1;            
          when readByte1 =>
            spiDataRdy  <= '1';
            contMode <= '1';            
            bin(15 downto 8) <= spiDataIn;
            state := readByte2;              
          when readByte2 =>
            spiDataRdy  <= '1';
            contMode <= '0';            
            bin(23 downto 16) <= spiDataIn;
            state := readByte3;                
          when readByte3 =>
            bin(31 downto 24) <= spiDataIn;
            state := waiting;
        end case; 
      end if;
    end if;
  end process;  
  
  displayInterface : segsDisplayInterface
    generic map ( FREQ => FREQ, COLS => 8, DITS => 8, PPOS => 0 )
    port map ( rst_n => rst_n, clk => clk, bin => bin, an_n => an_n, segs_n => segs_n );   
  
end syn;
