----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.2
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity NoteGen is
generic (
    WL : natural;
	BASE_NOTE_FREQ	:	real;
	HALF_STEP_NOTE_FREQ	:	real;
	WHOLE_STEP_NOTE_FREQ	:	real
	
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    note_in                 : in    std_logic_vector(7 downto 0);  -- 
    interpolateSampleRqt    : in    std_logic; --
    sample_out              : out    std_logic_vector(WL-1 downto 0);
    
    --Mem side
    samples_in              :   in  std_logic_vector(WL-1 downto 0);
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
    readMem_out             :   out std_logic;
    sampleRqtOut_n          :   out std_logic
  );
end NoteGen;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.my_common.all;

architecture Behavioral of NoteGen is
	
	signal noteAddr : unsigned(25 downto 0);

begin
--	constant	QM_ARITH	:	natural	:=	32;
--	constant	QN			:	nautral	:= WL - QM;
--	constant	MAX_POSITIVE_VAL	:	std_logic_vector(QN+QM-2 downto 0) := (others=>'1');
--	constant	MAX_NEGATIVE_VAL	:	std_logic_vector(QN+QM-2 downto 0) := (others=>'0');
--
--	signal ci								:	signed(2*QM_ARITH-1 downto 0);
--	signal	subVal, truncateVal				:	signed(WL downto 0);
--	signal	mulVal, addVal, roundVal		:	signed(QM_ARITH+WL-1 downto 0);
--	signal	decimalPart						:	signed(QM_ARITH downto 0);
--	signal	finalVal						:	signed(WL-1 downto 0);
--
--
--	Interpolate:
--		subVal <= (wtinIPlus1(WL-1) & wtinIPlus1) + (wtinI(WL-1) & wtinI);
--		mulVal <= decimalPart * (subVal sll (QM_ARITH-QM));
--		addVal <= ((wtinI(WL-1) & wtinI) sll QM_ARITH) + mulVal;
--		roundVal <= addVal + '1' sll (QM_ARITH-1);
--		truncateVal <= roundVal(WL downto QM_ARITH-QM);
--		finalVal <= signed(('0' & MAX_POSITIVE_VAL)) when truncateVal(WL downto WL-1) = "01" else
--					signed(('1' & MAX_NEGATIVE_VAL)) when truncateVal(WL downto WL-1) = "10" else
--					signed(truncateVal(WL) & truncateVal(WL-2 dwonto 0));
--
--	decimalPart <= ci(31 downto 0);
--
--	with note_in(7 downto 6) select
--				ci <=  toFix(HALF_STEP_NOTE_FREQ/BASE_NOTE_FREQ,QM_ARITH,QM_ARITH) when "01",
--						toFix(WHOLE_STEP_NOTE_FREQ/BASE_NOTE_FREQ,QM_ARITH,QM_ARITH) when X"10",
--						0 when others;
--
--
--
    
	noteAddr <= (others=>'0');
	
	filterRegisters :
  process (rst_n, clk)
      type states is (idle, getSamples, interpolate, calculateNextStep); 
      variable state: states;
      variable cntr : unsigned(3 downto 0);
      variable currentAddr : unsigned(25 downto 0);
      variable wtinI,wtinIPlus1 : signed(WL-1 downto 0);
      variable wtout : signed(WL-1 downto 0);
  begin  
    
    addr_out <= std_logic_vector(currentAddr);
    sample_out <= std_logic_vector(wtout);
    
    sampleRqtOut_n <= '1';
    readMem_out <= '1';

    if state=getSamples and (cntr=0 or cntr=2) then
      sampleRqtOut_n <= '0';
      readMem_out <= '0';      
    end if;
    
    if rst_n='0' then
        state := idle;
        cntr :=(others => '0');
        currentAddr := (others=>'0');
        wtout := (others=>'0');
	elsif rising_edge(clk) then
        
        if cen_in='0' then
            state := idle;
        else
            case state is
            
                -- Wait interpolateSampleRqt
                when idle =>
                    if cen_in='1' then
                        cntr :=(others => '0');
                        currentAddr := noteAddr;
                        state := getSamples;
                    end if;
            
                -- Recive samples, stay in this state until I recive two samples
                -- I use cntr to modify the moore output w
                when getSamples =>
                    
                    if cntr=0 or cntr=2 then
                        cntr := cntr+1;
                    elsif memAck='1' then 
                        currentAddr := currentAddr+1;
                        if cntr=1 then
                            cntr := cntr+1;
                            wtinI := signed(samples_in);
                        elsif cntr=3 then
                            cntr := cntr+1;
                            wtinIPlus1 := signed(samples_in);
                            state := interpolate;
                        end if;
                    end if;
            
                when interpolate =>
                    if interpolateSampleRqt ='1' then
                        wtout := wtinI;
                        state := calculateNextStep;
                    end if;
                    
                when calculateNextStep =>
                        cntr :=(others => '0');
                        currentAddr := currentAddr-1; -- This because is a test
                        state := getSamples;
            
                end case;
          end if; --If cen_in='0'
    end if; 
  end process;
        
end Behavioral;

