-------------------------------------------------------------------
--
--  Fichero:
--    sioMaster.vhd  13/12/2017
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Conversor elemental de paralelo a una linea serie SPI y
--    viceversa con protocolo de strobe
--
--  Notas de diseño:
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity spiMaster is
  generic (
    FREQ      : natural;    -- frecuencia de operacion en KHz
    BAUDRATE  : natural;    -- velocidad de comunicacion
    WIDTH     : natural;    -- anchura de datos
    CPOL      : std_logic;  -- polaridad del reloj (valor en inactivo)
    CPHA      : std_logic  -- fase del reloj: 1 = vuelca en flancos impares (1,3,7...) y muestrea en pares (2,4,6...), 0 = vuelca en pares y muestrea en impares
  );
  port (
    -- host side
    rst_n    : in  std_logic;   -- reset asíncrono del sistema (a baja)
    clk      : in  std_logic;   -- reloj del sistema
    contMode : in  std_logic;   -- indica si la transferencia se hace de modo continuo (es decir, sin deseleccionar el dispositivo su finalización)
    dataRdy  : in  std_logic;   -- se activa durante 1 ciclo para solicitar la transmisión/recepción de un dato
    dataIn   : out std_logic_vector (WIDTH-1 downto 0);   -- dato recibido
    dataOut  : in  std_logic_vector (WIDTH-1 downto 0);   -- dato a transmitir
    busy      : out std_logic;   -- se activa desde el ciclo siguiente en que lo hace 'dataRdy' hasta que finaliza la transmisión/recepción (salida tipo moore)
    earlyBusy : out std_logic;   -- se activa desde el mismo ciclo en que lo hace 'dataRdy' hasta que finaliza la transmisión/recepción (salida tipo mealy)
    -- SPI side
    sck      : out std_logic;   -- reloj serie
    ss_n     : out std_logic;   -- selección de esclavo
    miso     : in  std_logic;   -- master in / slave out
    mosi     : out std_logic    -- master out / slave in
  );
end spiMaster;

-------------------------------------------------------------------

architecture syn of spiMaster is

  -- Registros
  signal misoShf : std_logic_vector (WIDTH-1 downto 0);
  signal mosiShf : std_logic_vector (WIDTH-1 downto 0);
  signal bitPos : natural range 0 to WIDTH-1;   
  -- Señales
  signal baudCntCE, baudCntTC : std_logic;
  signal cntMaxValue : natural;
  
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

  mosi   <= mosiShf(WIDTH-1);
  dataIn <= misoShf;

  fsmd :
  process (rst_n, clk, dataRdy)
    type states is (waiting, selection, firstHalf, secondHalf, continue, unselection); 
    variable state: states;
  begin
    baudCntCE <= '1';
    earlyBusy <= '1';
    busy      <= '1';    
    if state=waiting or state=continue then
      baudCntCE <= '0';
      earlyBusy <= dataRdy;  -- se activa desde el mismo ciclo en que lo hace dataRd
      busy      <= '0';      -- se activa desde el ciclo siguiente al que lo hace dataRd
    end if;            
    if rst_n='0' then
      sck     <= CPOL;  -- se registra para evitar posibles glitches
      ss_n    <= '1';   -- idem
      misoShf <= (others => '0');
      mosiShf <= (others => '0');
      bitPos  <= 0;
      state   := waiting;
    elsif rising_edge(clk) then
      case state is
        when waiting =>                             -- Espera solicitud de transmisión
          sck  <= CPOL;
          ss_n <= '1';
          if dataRdy='1' then
            misoShf <= (others => '0');
            mosiShf <= dataOut;
            state   := selection;
          end if;
        when selection =>                           -- Selecciona esclavo
          sck  <= CPOL;
          ss_n <= '0';
          if baudCntTC='1' then
            bitPos <= 0;
            state  := firstHalf;
            if CPHA='0' then                        -- Si CPHA='0' lee miso
              misoShf <= misoShf(WIDTH-2 downto 0) & miso;
            end if;   
          end if;           
        when firstHalf =>                           -- Genera flanco impar y desplaza justo antes de la generación del siguiente flanco
          sck  <= not CPOL;
          ss_n <= '0';
          if baudCntTC='1' then
            state := secondHalf;
            if CPHA='0' then                        -- Si CPHA='0' escribe mosi
              mosiShf <= mosiShf(WIDTH-2 downto 0) & '0';             
            else                                    -- Si CPHA='1' lee miso
              misoShf <= misoShf(WIDTH-2 downto 0) & miso;             
            end if;
          end if; 
        when secondHalf =>                          -- Genera flanco par y desplaza justo antes de la generación del siguiente flanco
          sck  <= CPOL;
          ss_n <= '0';
          if baudCntTC='1' then
            if bitPos=WIDTH-1 then
              if contMode = '1' then
                state := continue;
              else
                state := unselection;
              end if;
            else
              bitPos <= bitPos + 1;
              state  := firstHalf;
              if CPHA='0' then                      -- Si CPHA='0' lee miso
                misoShf <= misoShf(WIDTH-2 downto 0) & miso;             
              else                                  -- Si CPHA='1' escribe mosi
                mosiShf <= mosiShf(WIDTH-2 downto 0) & '0';             
              end if;
            end if;
          end if;
        when continue =>                            -- Espera nuevo dato a transmitir
          sck  <= CPOL;
          ss_n <= '0';
          if dataRdy='1' then
            bitPos <= 0;
            misoShf <= (others => '0');
            mosiShf <= dataOut;
            state   := firstHalf;
          end if;           
        when unselection =>                         -- Deselecciona esclavo
          sck  <= CPOL;
          ss_n <= '1';
          if baudCntTC='1' then
            state := waiting;
          end if; 
        end case;
    end if;
  end process;
   
end syn;
