----------------------------------------------------------------------------------
-- MEM TEST

-- Writes all RAM, then reads and checks for errors.
-- 7 SEG: Right -> Data IN/OUT, Left -> Expected data
-- 16 bit word
-- MIG: PHY 4:1 (75 Mhz ui_clk), 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity memTest is
  port (clk_i          : in  std_logic;
        resetn_i         : in  std_logic;
        -- switch
        btnc_i             : in  std_logic;
        sw_i              : in  std_logic;
        -- 7-segment display
        disp_seg_o     : out std_logic_vector(7 downto 0);
        disp_an_o      : out std_logic_vector(7 downto 0);
        -- leds
        led_o          : out std_logic_vector(15 downto 0);
        
        -- DDR2 interface signals
        ddr2_addr      : out   std_logic_vector(12 downto 0);
        ddr2_ba        : out   std_logic_vector(2 downto 0);
        ddr2_ras_n     : out   std_logic;
        ddr2_cas_n     : out   std_logic;
        ddr2_we_n      : out   std_logic;
        ddr2_ck_p      : out   std_logic_vector(0 downto 0);
        ddr2_ck_n      : out   std_logic_vector(0 downto 0);
        ddr2_cke       : out   std_logic_vector(0 downto 0);
        ddr2_cs_n      : out   std_logic_vector(0 downto 0);
        ddr2_dm        : out   std_logic_vector(1 downto 0);
        ddr2_odt       : out   std_logic_vector(0 downto 0);
        ddr2_dq        : inout std_logic_vector(15 downto 0);
        ddr2_dqs_p     : inout std_logic_vector(1 downto 0);
        ddr2_dqs_n     : inout std_logic_vector(1 downto 0)
        );
		
-- Attributes for debug
attribute   dont_touch    :   string;
attribute   dont_touch  of  memTest  :   entity  is  "true";   
		
end memTest;

use work.my_common.all;

architecture syn of memTest is
----------------------------------------------------------------------------------
-- Component Declarations
---------------------------------------------------------------------------------- 

-- 200 MHz Clock Generator
component ClkGen
  port (-- Clock in ports
        clk_100MHz_i           : in     std_logic;
        -- Clock out ports
        clk_200MHz_o          : out    std_logic;
        -- Status and control signals
        resetn             : in     std_logic;
        locked            : out    std_logic
        );
end component;


----------------------------------------------------------------------------------
-- Signals Declarations
---------------------------------------------------------------------------------- 
 
-- Reset signals
signal reset                : std_logic;
signal reset_sync           : std_logic;
signal rst_n                : std_logic;
signal rst                  : std_logic;
signal locked               : std_logic;

-- 200 MHz buffered clock signal
signal clk_200MHz           : std_logic;

-- 7 segs
signal segRight_n0,segRight_n1,segRight_n2,segRight_n3                : std_logic_vector(5 downto 0);
signal segLeft_n0,segLeft_n1,segLeft_n2, segLeft_n3              : std_logic_vector(5 downto 0);


-- Buttons
signal  memBeginTest    :   std_logic;


-- RamCntrl
signal  rdWr    :   std_logic;
signal  ui_clk  :   std_logic;

-- Buffers and signals to manage the read request commands
signal  inCmdReadBuffer_0     	:	std_logic_vector(26 downto 0); -- For midi parser component 
signal  wrRqtReadBuffer_0     	:	std_logic; 
signal  fullCmdReadBuffer_0		:	std_logic;

signal  inCmdReadBuffer_1     	:	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
signal  wrRqtReadBuffer_1       :    std_logic;
signal  fullCmdReadBuffer_1     :    std_logic;

-- Buffers and signals to manage the read response commands
signal	rdRqtReadBuffer_0		:	std_logic;
signal	outCmdReadBuffer_0		:	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
signal	emptyResponseRdBuffer_0	:	std_logic;

signal	rdRqtReadBuffer_1		:	std_logic;
signal	outCmdReadBuffer_1		:	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
signal	emptyResponseRdBuffer_1	:	std_logic;	 
    
-- Buffer and signals to manage the writes commands
signal    inCmdWriteBuffer   :    std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
signal    wrRqtWriteBuffer   :    std_logic;
signal    fullCmdWriteBuffer, emptyCmdWriteBufferOut :    std_logic;
signal    writeWorking       :    std_logic; -- High when the RamCntrl is executing some write command, low when no writes 


-- FSM
signal  finishCheck :   std_logic;


-- Debug
--signal caheAddr             :   std_logic_vector(22 downto 0);
signal led_o_aux            : std_logic_vector(7 downto 0);
signal data_OutMem                 : std_logic_vector(15 downto 0);
signal ledsDDR              : std_logic_vector(5 downto 0);

begin
 
----------------------------------------------------------------------------------
-- 200MHz Clock Generator
----------------------------------------------------------------------------------
Inst_ClkGen: ClkGen
port map (clk_100MHz_i   => clk_i,
          clk_200MHz_o   => clk_200MHz,
          resetn        => resetn_i,
          locked       => locked
          );

----------------------------------------------------------------------------------
-- Reset Sync
----------------------------------------------------------------------------------
resetSyncronizer : synchronizer
generic map ( STAGES => 2, INIT => '0' )
port map ( rst_n => resetn_i, clk => clk_200MHz, x => '1', xSync => reset_sync );

-- Assign reset signals conditioned by the PLL lock
rst <= (not reset_sync) or (not locked);
rst_n <= not rst;


------------------------------------------------------------------------
-- Memory
------------------------------------------------------------------------
Ram: RamCntrl
   port map(                    					
      -- Common                 
      clk_200MHz_i				=> clk_200MHz,
      rst_n      				=> rst_n,
      ui_clk_o    				=> ui_clk,
      ledsDDR                   => ledsDDR,
      
      -- Ram Cntrl Interface
	  rdWr						=> rdWr,  -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	=> inCmdReadBuffer_0, -- For midi parser component 
	  wrRqtReadBuffer_0     	=> wrRqtReadBuffer_0, 
	  fullCmdReadBuffer_0		=> fullCmdReadBuffer_0, 
								 
	  inCmdReadBuffer_1     	=> inCmdReadBuffer_1, -- For KeyboardCntrl component
      wrRqtReadBuffer_1         => wrRqtReadBuffer_1, 
      fullCmdReadBuffer_1       => fullCmdReadBuffer_1, 
      
      -- Buffers and signals to manage the read response commands
      rdRqtReadBuffer_0            => rdRqtReadBuffer_0,
      outCmdReadBuffer_0           => outCmdReadBuffer_0,-- Cmd response buffer for Midi parser component
      emptyResponseRdBuffer_0      => emptyResponseRdBuffer_0,
                                
      rdRqtReadBuffer_1            => rdRqtReadBuffer_1,
      outCmdReadBuffer_1           => outCmdReadBuffer_1,-- Cmd response buffer for KeyboardCntrl component
      emptyResponseRdBuffer_1      => emptyResponseRdBuffer_1,

      -- Buffer and signals to manage the writes commands
      inCmdWriteBuffer            => inCmdWriteBuffer,-- For setup component and store midi file BL component
      wrRqtWriteBuffer            => wrRqtWriteBuffer,
      fullCmdWriteBuffer          => fullCmdWriteBuffer,
      emptyCmdWriteBufferOut      => emptyCmdWriteBufferOut,
      writeWorking                => writeWorking, -- High when the RamCntrl is executing some write command, low when no writes 
		
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



---------------------------------
-- Buttons Debouncers:
---------------------------------
sw0deb : Dbncr
generic map (NR_OF_CLKS  => 4095)
port map (clk_i    => ui_clk,
          sig_i    => btnc_i,
          pls_o    => memBeginTest
          );

----------------------------------------------------------------------------------
-- Seven-Segment Display and Leds
----------------------------------------------------------------------------------     
	sSegs : bin2segNexsys4 
port map (         
    clk => ui_clk,
     
    -- Right Side
    segRight_n0 => segRight_n0,--n0 ,
    segRight_n1 => segRight_n1, --n1,
    segRight_n2 => segRight_n2,
    segRight_n3 => segRight_n3,

    -- Left Side
    segLeft_n0 => segLeft_n0,
    segLeft_n1 => segLeft_n1,
    segLeft_n2 => segLeft_n2,
    segLeft_n3 => segLeft_n3,

    -- Out signals
    disp_seg_o => disp_seg_o, 
    disp_an_o => disp_an_o
 );



    segRight_n0 <= "10" & inCmdWriteBuffer(3 downto 0);
    segRight_n1 <= "10" & inCmdWriteBuffer(7 downto 4); 
    segRight_n2 <=  "10" & inCmdWriteBuffer(11 downto 8);
    segRight_n3 <=  "10" & inCmdWriteBuffer(15 downto 12); 

    -- Left Side,
    segLeft_n0 <= "10" & outCmdReadBuffer_1(3 downto 0); 
    segLeft_n1 <=  "10" & outCmdReadBuffer_1(7 downto 4);
    segLeft_n2 <=  "10" & outCmdReadBuffer_1(11 downto 8);
    segLeft_n3 <=  "10" & outCmdReadBuffer_1(15 downto 12);  

	led_o <= ledsDDR & emptyCmdWriteBufferOut & writeWorking & led_o_aux;




----------------------------------------------------------------------------------
-- FSM Read from the response buffer 1
-- It's also control the finishCheck
----------------------------------------------------------------------------------
--cucu:
--process(rst_n, ui_clk,memBeginTest)
--    constant MAX_ADDR : unsigned (25 downto 0) := (others=>'1');
    
--    type state_type is (Idle,Check,Err);
--    variable state : state_type;
        
--    variable dataInVal : unsigned (15 downto 0);
--    variable addrVal : unsigned (25 downto 0);

--begin
---- Debug
    
--    led_o_aux(7 downto 5) <=(others=>'0');
--    if state = Idle then
--        led_o_aux(5)<= '1' ;
--    end if;
    
--    if state = Check then
--        led_o_aux(6)<= '1' ;
--    end if;

--    if state = Err then
--        led_o_aux(7)<= '1' ;
--    end if;
---- debug

--  -- Mealy
--  rdRqtReadBuffer_1<='0';
--  if state=Check and emptyResponseRdBuffer_1='0' then
--    rdRqtReadBuffer_1<='1';
--  end if;
  
--  finishCheck <='1';
--  if state/=Idle then
--      finishCheck <='0';
--  end if;

--  if rst_n = '0' then
--    state := Idle;
    
--  elsif rising_edge(ui_clk) then

--        case state is
           
--           when Idle =>
--                if memBeginTest ='1' then
--                    state := Check;
--                end if;
                
--           when Check =>
--                 if emptyResponseRdBuffer_1='0' then
--                    if outCmdReadBuffer_1(15 downto 0)=std_logic_vector(dataInVal) then
--                        if addrVal=MAX_ADDR then
--                            state :=Idle;                            
--                        else                        
--                            addrVal := addrVal+1;
--                            dataInVal := dataInVal+1;
--                        end if;
                        
--                    else
--                        state := Err;
--                    end if;-- outCmdReadBuffer_1(15 downto 0)=std_logic_vector(dataInVal)
                                        
--                 end if;
        
--           when Err =>

        
--        end case;
        
--  end if;
--end process;

----------------------------------------------------------------------------------
-- FSM Send write and read cmds to memory
-- It's also control the rdWr
---------------------------------------------------------------------------------- 
FSM:
process(rst_n, ui_clk,finishCheck)
    type state_type is (Idle,FillMem,waitUntilFillMem,SendReadCmd,Check,waitFinishCheck,Err);
    constant MAX_ADDR : unsigned (25 downto 0) := (others=>'1');
    
    variable state : state_type;
    variable addrVal : unsigned (25 downto 0);
	variable temp : unsigned (17 downto 0);
    variable dataInVal : unsigned (15 downto 0);
    
--    variable noteGenIndex   :   unsigned(6 downto 0);
begin

-- Debug
    led_o_aux(4 downto 0) <=(others=>'0');
    led_o_aux(7 downto 5) <=(others=>'0');

    if state = Idle then
        led_o_aux(0)<= '1' ;
    end if;
    
    if state = FillMem then
        led_o_aux(1)<= '1' ;
    end if;
    
    if state = waitUntilFillMem then
            led_o_aux(2)<= '1' ;
    end if;   

    if state = SendReadCmd then
        led_o_aux(3)<= '1' ;
    end if;
    
    if state = waitFinishCheck then
        led_o_aux(4)<= '1' ;
    end if;
    
    if state = Check then
        led_o_aux(6)<= '1' ;
    end if;

    if state = Err then
        led_o_aux(7)<= '1' ;
    end if;
-- debug


  -- Mealy
    inCmdWriteBuffer<= std_logic_vector(addrVal) & std_logic_vector(dataInVal);
    wrRqtWriteBuffer <='0';
    if state=FillMem and fullCmdWriteBuffer='0' then
        wrRqtWriteBuffer <='1';
    end if;
    
    inCmdReadBuffer_1 <="000" & X"0" & std_logic_vector(addrVal);
    wrRqtReadBuffer_1 <='0';
    if state=SendReadCmd and fullCmdReadBuffer_1='0' then
        wrRqtReadBuffer_1 <='1';
    end if;
        
    rdRqtReadBuffer_1<='0';
    if state=Check and emptyResponseRdBuffer_1='0' then
        rdRqtReadBuffer_1<='1';
    end if;

  if rst_n = '0' then
    state := Idle;
    addrVal := (others=>'0');
    dataInVal := (others=>'0');
    rdWr <='0';--write mode

  elsif rising_edge(ui_clk) then
        
        if temp/=0 then
            temp := temp-1;
        else
            case state is
               when Idle =>
                    if memBeginTest ='1' then
                        state := FillMem;
                        rdWr <='0';--write mode

                    end if;
                    
               when FillMem =>
                    if fullCmdWriteBuffer='0' then
                        if sw_i='1' then
                            temp :=(others=>'1');
                        end if;
                        
                        if addrVal=MAX_ADDR then
                            state :=waitUntilFillMem;                            
                        else
                            addrVal := addrVal+1;
                            dataInVal := dataInVal+1;
                        end if;
                    end if;
                
            
               when waitUntilFillMem =>
                    if emptyCmdWriteBufferOut='1' and writeWorking='0' then
                        rdWr <='1';--read mode
                        addrVal := (others=>'0');
                        dataInVal := (others=>'0');
                        state :=SendReadCmd;
                    end if;
                    
               when SendReadCmd =>
                    if fullCmdReadBuffer_1='0' then
                        if sw_i='1' then
                            temp :=(others=>'1');
                        end if;
                        state :=Check;                            
                    end if;
                    
               when Check =>
                    if emptyResponseRdBuffer_1='0' then
                        if outCmdReadBuffer_1(15 downto 0)=std_logic_vector(dataInVal) then

                            if addrVal=MAX_ADDR then
                                state :=Idle;                            
                            else
                                addrVal := addrVal+1;
                                dataInVal := dataInVal+1;
                                state :=SendReadCmd;                            
                            end if;
                        else
                            state := Err;
                            
                        end if;
                    end if;
                    
               when Err =>
               
               
               when waitFinishCheck=>
--                    if finishCheck='1' then
--                        state := idle;
--                    end if;
                  
            end case;
            
        end if;--temp/=0
  end if;
end process FSM;


end syn;
