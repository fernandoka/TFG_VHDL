----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.3
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

entity InterpolatedNoteGen is
generic (
    WL 			: 	natural;
	QM			:	natural;
	START_ADDR	:	natural;
    END_ADDR	:	natural;
	TARGET_NOTE	:	real;
	BASE_NOTE	:	real
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    interpolateSampleRqt    : in    std_logic;
    sample_out              : out    std_logic_vector(WL-1 downto 0);
    
    --Mem side
    samples_in              :   in  std_logic_vector(WL-1 downto 0);
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
    readMem_out             :   out std_logic
  );
end InterpolatedNoteGen;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.my_common.all;

architecture Behavioral of InterpolatedNoteGen is
---------------------------	CONSTANTS --------------------------------------
	constant QN				:	natural	:=	WL-QM;
	constant Q_N_M_ARITH 	:	natural := 32;
	
	constant ZEROS 			:	signed(Q_N_M_ARITH-1 downto 0) := (others=>'0');
	constant VALUE_TO_ROUND :	signed(Q_N_M_ARITH-1 downto 0) := to_signed(2**Q_N_M_ARITH,Q_N_M_ARITH);
	constant MAX_VAL_SAMPLE	:	std_logic_vector(WL-2 downto 0) := (others=>'1');
	
	constant STEP_VAL		:	signed(2*Q_N_M_ARITH-1 downto 0) := toFix(TARGET_NOTE/BASE_NOTE,Q_N_M_ARITH,Q_N_M_ARITH);
	
---------------------------	SIGNALS	--------------------------------------
	-- Registers
	signal wtinI,wtinIPlus1 : signed(WL-1 downto 0);

	
	--signal	subVal							:	signed(QM+QN downto 0); -- 17 bits
	--signal	addVal, roundVal, mulVal        :	signed(Q_N_M_ARITH+QM+QN+1 downto 0); -- 48 bits
	--signal	finalVal						:	signed(QM+QN-1 downto 0);-- 16 bits
	
	--signal	decimalPart						:	signed(Q_N_M_ARITH downto 0);-- 33 bits, msb de signo
	--signal	ci								:	signed(2*Q_N_M_ARITH-1 downto 0);-- 64 bits	
	
	--Versión sudando de todo
	signal	subVal							:	signed(QM+QN-1 downto 0); -- 16 bits
	signal	addVal, roundVal, mulVal        :	signed(Q_N_M_ARITH+QM+QN-1 downto 0); -- 48 bits
	signal	finalVal						:	signed(QM+QN-1 downto 0);-- 16 bits
	
	signal	decimalPart						:	signed(Q_N_M_ARITH downto 0);-- 33 bits, msb de signo
	signal	ci								:	signed(2*Q_N_M_ARITH-1 downto 0);-- 64 bits	
	
begin	
		
--	Interpolation :
--		subVal <= (wtinIPlus1(WL-1) & wtinIPlus1) - (wtinI(WL-1) & wtinI); -- Q2.15 = Q1.15+Q1.15
--		
--		mulVal <= decimalPart*subVal; -- Q2.47 = Q2.15+Q0.32
--		
--		addVal <= mulVal + (wtinI(WL-1) & wtinI & ZEROS); -- Q2.47 = Q2.47+Q2.47( (Q2.15<<Q_N_M_ARITH)), Wrap here!!  
--	
--		roundVal <= (addVal + VALUE_TO_ROUND); -- Wrap here!!
--			
--		satur:
--			finalVal <= signed("0" & MAX_VAL_SAMPLE) when roundVal(Q_N_M_ARITH+QM+QN+1 downto Q_N_M_ARITH) > signed("000" & MAX_VAL_SAMPLE) else -- MAX_POS_VAL
--						signed("1" & not MAX_VAL_SAMPLE) when roundVal(Q_N_M_ARITH+QM+QN+1 downto Q_N_M_ARITH) < signed("111" & not MAX_VAL_SAMPLE) else -- MAX_NEG_VAL
--						roundVal(Q_N_M_ARITH+QM+QN-1 downto Q_N_M_ARITH);
--						
--						
--		decimalPart	<= "0" & ci(Q_N_M_ARITH-1 downto 0); -- Siempre Positivo

-- Otro intento, sudando de todo
	Interpolation :
		subVal <= wtinIPlus1 - wtinI; -- Wrap here!!
		
		mulVal <= decimalPart*subVal;
		
		addVal <= mulVal + signed(wtinI & ZEROS);  -- Wrap here!!
	
		roundVal <= (addVal + VALUE_TO_ROUND); -- Wrap here!!
			
		finalVal <= roundVal(Q_N_M_ARITH+QM+QN-1 downto Q_N_M_ARITH); -- Wrap here!!
						
						
		decimalPart	<= signed("0" & ci(Q_N_M_ARITH-1 downto 0)); -- Siempre Positivo

	
	filterRegisters :
  process (rst_n, clk)
      type states is (idle, getSample1, getSample2, interpolate, calculateNextStep); 
      variable state: states;
      variable cntr : natural range 0 to 1;
      variable currentAddr : natural range START_ADDR to END_ADDR;
      variable wtout : signed(QM+QN-1 downto 0);
  begin  
    
    addr_out <= (others=>'0');
    addr_out <= std_logic_vector(to_unsigned(currentAddr,26));
    sample_out <= std_logic_vector(wtout);

    if rst_n='0' then
        state := idle;
        cntr := 0;
        currentAddr := START_ADDR;
        wtout := (others=>'0');
        wtinIPlus1 <= (others=>'0');
        wtinI <= (others=>'0');
		ci <=(others=>'0');
        readMem_out <= '1';
                
	elsif rising_edge(clk) then
        readMem_out <= '1';
            
        if cen_in='0' then
            state := idle;
        else
            case state is
                    
                when idle =>
                    if cen_in='1' then
                        cntr := 0;
                        wtout := (others=>'0');
                        ci <=(others=>'0');
						currentAddr := START_ADDR;
                        state := getSample1;
                        -- Prepare read
                        readMem_out <= '0';
                    end if;
            
                -- Recive samples
                when getSample1 =>
                    
                    if memAck='1' then 
                        currentAddr := currentAddr+1;
                        wtinI <= signed(samples_in);
                        state := getSample2;
                        -- Prepare read
                       readMem_out <= '0';
                    end if;
            
            
                when getSample2 =>
                   if memAck='1' then 
                       currentAddr := currentAddr+1;
                       wtinIPlus1 <= signed(samples_in);
                       state := interpolate;
                  end if;
                
                -- Wait 2 SampleRqt because the audio is mono
                when interpolate =>
                    if cntr=0 and interpolateSampleRqt ='1' then
                        cntr :=cntr+1;
                        ci	  <= ci+STEP_VAL; -- Calculate next step
                    elsif cntr=1 and interpolateSampleRqt ='1' then
                        wtout := finalVal;
                        currentAddr := START_ADDR+to_integer(ci(2*Q_N_M_ARITH-1 downto Q_N_M_ARITH)); -- Calculate next addr
                        state := calculateNextStep;
                    end if;
                    
                when calculateNextStep =>
                        cntr := 0;
                        if currentAddr >= END_ADDR then 
                            currentAddr := START_ADDR; -- This because is a test
                            ci <=(others=>'0');	
                        end if;
                        state := getSample1;
                        -- Prepare read
                        readMem_out <= '0';
            
                end case;
          end if; --If cen_in='0'
    end if; 
  end process;
        
end Behavioral;

