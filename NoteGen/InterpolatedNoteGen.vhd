----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.5
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity InterpolatedNoteGen is
generic (
	START_ADDR	:	unsigned(25 downto 0);
    END_ADDR	:	unsigned(25 downto 0);
    TARGET_NOTE :   real;
    BASE_NOTE   :   real
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    interpolateSampleRqt    : in    std_logic;
    sample_out              : out    std_logic_vector(15 downto 0);
    
    --Debug
    ciOut                      :   out std_logic_vector(63 downto 0);
    
    --Mem side
    samples_in              :   in  std_logic_vector(15 downto 0);
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
	constant VALUE_TO_ROUND :	signed(50 downto 0) :="000" & X"000100000000"; --to_signed(2**Q_N_M_ARITH,Q_N_M_ARITH);
	
    constant STEP_VAL		:	unsigned(63 downto 0) := X"0000000100000000" or toUnFix( (TARGET_NOTE/BASE_NOTE),32,32);
    
	constant   MAX_POS_VAL     :   signed(16 downto 0) := "0" & X"7FFF";
	constant   MAX_NEG_VAL     :   signed(16 downto 0) := "1" & X"0000";
---------------------------	SIGNALS	--------------------------------------
	-- Registers
	signal wtinI,wtinIPlus1 : signed(15 downto 0);

	
	signal finalVal						:	signed(15 downto 0);-- 16 bits
	signal subVal                       :   signed(16 downto 0);--17 bits
	signal mulVal                       :   signed(49 downto 0); -- 50 bits
    
    signal roundVal                     :   signed(50 downto 0); -- 51 bits
    signal addVal                       :   signed(16 downto 0);
	
	signal decimalPart				    :	signed(32 downto 0);-- 33 bits, msb de signo
	signal ci							:	unsigned(63 downto 0);-- 64 bits	
	
begin	

Interpolate:
    subVal <= (wtinIPlus1(15) & wtinIPlus1) - (wtinI(15) & wtinI); -- Q17.0 = Q16.0-Q16.0
    
    mulVal <= decimalPart*subVal; -- Q49.0 = Q17.0*Q33.0
    
    roundVal <= (mulVal(49) & mulVal) + VALUE_TO_ROUND; --Q50.0 = Q49.0+Q49.0
    
    addVal <= roundVal(50 downto 34) + (wtinI(15) & wtinI); --Q17.0 = Q16.0+Q16.0
    
    finalVal <= MAX_POS_VAL(15 downto 0) when addVal > MAX_POS_VAL else
                MAX_NEG_VAL(15 downto 0) when addVal < MAX_NEG_VAL else
                addVal(15 downto 0);


    decimalPart <= signed("0" & ci(31 downto 0));
	
ciOut <= std_logic_vector(STEP_VAL);

	filterRegisters :
  process (rst_n, clk,memAck,cen_in,interpolateSampleRqt)
      type states is (idle, getSample1, getSample2, interpolate, calculateNextStep); 
      variable state: states;
      variable cntr : natural range 0 to 1;
      variable currentAddr : unsigned(25 downto 0);
      variable wtout : signed(15 downto 0);
  begin  
    
    addr_out <= std_logic_vector(currentAddr);
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
                        currentAddr := START_ADDR+unsigned(ci(57 downto 32)); -- Calculate next addr
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

