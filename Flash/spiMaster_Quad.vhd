-------------------------------------------------------------------
--
--  Fichero:
--    sioMaster.vhd  13/12/2017
--
--    (c) J.M. Mendias
--    DiseÃ±o AutomÃ¡tico de Sistemas
--    Facultad de InformÃ¡tica. Universidad Complutense de Madrid
-- 
--  Retocado por Fernando Candelario para el desarrollo del TFG
--  VersiÃ³n: 0.5
--
--  Notas de diseÃ±o:
--      Fase de reloj establecida a 1, vuelca en flancos impares y muestrea en pares.
--      NÂº de dummyCycles = 8
--  
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity spiMaster_Quad is
  generic (
    FREQ      : natural;    -- frecuencia de operacion en KHz
    BAUDRATE  : natural    -- velocidad de comunicacion
  );
  port (
    -- host side
    rst_n    : in  std_logic;   -- reset asÃ­ncrono del sistema (a baja)
    clk      : in  std_logic;   -- reloj del sistema
    contMode : in  std_logic;   -- indica si la transferencia se hace de modo continuo (es decir, sin deseleccionar el dispositivo su finalizaciÃ³n)
    dataOutRdy  : in  std_logic;   -- se activa durante 1 ciclo para solicitar la transmisiÃ³n
    dataIn   : out std_logic_vector (7 downto 0);   -- dato recibido
    dataOut  : in  std_logic_vector (31 downto 0);   -- Se escribe la instruccion y la direccion de inicio ( Inst + Addr )
    dataInRdy_n : out std_logic;   -- Notifica la recepciÃ³n de cada byte leido
    busy        : out std_logic; -- Activo a 1 si el dispositivo esta funcionando, no esta en waiting
    
    -- SPI side
    sck      : out std_logic;   -- reloj serie
    ss_n     : out std_logic;   -- selecciÃ³n de esclavo
    io0      : inout std_logic;   
    io1_in      : in  std_logic; -- Solo leo  
    io2_in      : in std_logic; -- Solo leo
    io3_in      : in std_logic -- Solo leo  
    );
end spiMaster_Quad;

-------------------------------------------------------------------

architecture syn of spiMaster_Quad is
    
    
  -- Constantes
  constant CPOL : std_logic := '1'; -- polaridad del reloj (valor en inactivo)
  constant CPHA : std_logic := '1';   -- fase del reloj: 1 = vuelca en flancos impares (1,3,7...) y muestrea en pares (2,4,6...), 0 = vuelca en pares y muestrea en impares
  constant DUMMY_CYCLES : natural := 8;
  
  -- Registros
  signal io0Shf_out : std_logic_vector (31 downto 0);
  signal bitPos : natural range 0 to 31;
     
  signal sendFlag : std_logic;

  signal io0Shf_in,io1Shf_in,io2Shf_in,io3Shf_in : std_logic_vector(1 downto 0);
  
  -- SeÃ±ales
  signal baudCntCE, baudCntTC : std_logic;
  signal cntMaxValue : natural;
  signal io0_in: std_logic;
  
begin

  cycleCounter :
  process (rst_n, clk, cntMaxValue)
    constant numCycles : natural := (FREQ*1000)/BAUDRATE;
    constant maxValue  : natural := numCycles/2-1; -- divide entre 2 para generar ambos flancos
    variable count     : natural range 0 to maxValue;
  begin
      baudCntTC <= '0';
      if count = maxValue then
        baudCntTC <= '1';
      end if;
      if rst_n='0' then
        count := 0;
      elsif rising_edge(clk) then
        if baudCntCE='0' then
          count := 0;
        else
          if baudCntTC='1' then
            count := 0;
          else
            count := count + 1;
          end if;
        end if;
      end if;
    end process; 

  io0 <= io0Shf_out(31) when sendFlag='1' else 'Z';
  io0_in <= io0 when sendFlag='0' else 'Z';
    
  dataIn <= io3Shf_in(1) & io2Shf_in(1) & io1Shf_in(1) & io0Shf_in(1) &
             io3Shf_in(0) & io2Shf_in(0) & io1Shf_in(0) & io0Shf_in(0);

  fsmd :
  process (rst_n, clk, dataOutRdy)
    type states is (waiting, selection, firstHalfWR, secondHalfWR, firstDummyHalf, secondDummyHalf,
                    firstHalfRD, secondHalfRD, unselection); 
    variable state: states;
    variable stateToEnd : states;
  begin
    baudCntCE <= '1';
    busy <='1';
  
  if state=waiting then
    baudCntCE <= '0';
    busy <= '0';
  end if;
  
  
  
  if rst_n='0' then
    sck     <= CPOL;  -- se registra para evitar posibles glitches
    ss_n    <= '1';   -- idem
    io1Shf_in <= (others => '0');
    io2Shf_in <= (others => '0');
    io3Shf_in <= (others => '0');
    io0Shf_out <= (others => '0');
    sendFlag <= '1'; -- Este quizas no es necesario
    bitPos  <= 0;
    state   := waiting;

  elsif rising_edge(clk) then

    dataInRdy_n <='1'; -- Se asegura que solo dure un ciclo

    case state is
      
      -- Espera solicitud de transmisión
      when waiting =>
        sck  <= CPOL;
        ss_n <= '1';
        if dataOutRdy='1' then
          io1Shf_in <= (others => '0');
          io2Shf_in <= (others => '0');
          io3Shf_in <= (others => '0');
          sendFlag <= '1';       
          io0Shf_out <= dataOut;
          state   := selection;
        end if;
        
      -- Selecciona esclavo
      when selection =>
        sck  <= CPOL;
        ss_n <= '0';
        if baudCntTC='1' then
          bitPos <= 0;
          state  := firstHalfWR;
        end if;
        
      -- Genera flanco impar, como solo quiero escribir no hago nada.            
      when firstHalfWR =>                           
        sck  <= not CPOL;
        ss_n <= '0';
        if baudCntTC='1' then
          state := secondHalfWR;
        end if;
      
      -- Genera flanco par, si ya he escrito los 32 bits ( Inst + Addr ) salto al estado de ciclos dummy 
      -- poniendo a bitPos a 0 para el siguiente ciclo, si no desplazo   
      when secondHalfWR =>                          
        sck  <= CPOL;
        ss_n <= '0';
        if baudCntTC='1' then
          if bitPos=31 then
              bitPos <= 0;
              state := firstDummyHalf;
          else
            bitPos <= bitPos + 1;
            state  := firstHalfWR;
            io0Shf_out <= io0Shf_out(30 downto 0) & '0';
          end if;
        end if;
      
      -- Espero 8 ciclos dummy, para ello uso bit pos contando los flancos de subida, es como si recibiera 1 Byte 
      when firstDummyHalf =>  
          sck  <= not CPOL;
          ss_n <= '0';
          if baudCntTC='1' then
              state := secondDummyHalf;
          end if;    
        
      when secondDummyHalf =>
          sck  <=  CPOL;
          ss_n <= '0';
          if baudCntTC='1' then            
              if bitPos = DUMMY_CYCLES-1 then
                state := firstHalfRD;
                stateToEnd := firstHalfRD; -- Por defecto empieza en continuo
                bitPos <= 0;
                sendFlag <= '0'; -- Para el triestado     
              else
                  bitPos <= bitPos+1;
                  state := firstDummyHalf;
              end if;
          end if;    

      -- Genera flanco impar, como quiero leer desplazo            
      when firstHalfRD =>                           
        sck  <= not CPOL;
        ss_n <= '0';
        if baudCntTC='1' then
          state := secondHalfRD;
          io0Shf_in <= io0Shf_in(0) & io0_in;
          io1Shf_in <= io1Shf_in(0) & io1_in;
          io2Shf_in <= io2Shf_in(0) & io2_in;
          io3Shf_in <= io3Shf_in(0) & io3_in;
    
          if bitPos=1 then
              dataInRdy_n <= '0';
          end if;
    
        end if;
      
      -- Genera flanco par, como solo quiero leer no escribo,
      -- como leo de 4 en 4, cuento hasta bitPos = 1, si contMode = 1
      -- continuo leyendo de forma continua, si no paso al estado de deseleccion de esclavo.
      -- En cuanto contMode este a un ciclo a baja, sera la lectura actual sera la ultima a realizar   
      when secondHalfRD =>                          
        sck  <= CPOL;
        ss_n <= '0';
                 
        if contMode = '0' then
          stateToEnd := unselection;
        end if;
        
        if baudCntTC='1' then
          if bitPos=1 then
              bitPos <= 0;
              state := stateToEnd;
          else
            bitPos <= bitPos + 1;
            state  := firstHalfRD;
          end if;
        end if;
        
    
      -- Deselecciona esclavo             
      when unselection =>                         
        sck  <= CPOL;
        ss_n <= '1';
        if baudCntTC='1' then
          state := waiting;
        end if; 
      end case;
      
  end if;
end process;
   
end syn;
