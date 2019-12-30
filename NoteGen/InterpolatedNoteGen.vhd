----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.7
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity InterpolatedNoteGen is
generic (
    FS              :   in real;
    TARGET_NOTE     :   in real;
    BASE_NOTE       :   in real;
    SUSTAIN_OFFSET  :   in natural;
    RELEASE_OFFSET  :   in natural;
    START_ADDR      :   in natural;
    END_ADDR        :   in natural
  );
  port(
    -- Host side
    rst_n                   : 	in	std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : 	in	std_logic;  -- reloj del sistema
    cen_in                  : 	in	std_logic;   -- Activo a 1
    interpolateSampleRqt    :	in	std_logic;
    sample_out              : 	out	std_logic_vector(15 downto 0);
	
	--Mem side
    samples_in              :   in  std_logic_vector(15 downto 0);
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
	sample_inRqt			:	out	std_logic	--	A 1 cuando espera una nueva muestra de memoria.
  );
end InterpolatedNoteGen;

use work.my_common.all;

architecture Behavioral of InterpolatedNoteGen is
---------------------------	CONSTANTS --------------------------------------
    
    constant    MAX_INTERPOLATED_SAMPLES		:	natural := integer( (real(END_ADDR-START_ADDR+1)/(TARGET_NOTE/BASE_NOTE))+0.5 );
    constant    SUSTAIN_START_OFFSET_ADDR       :   natural := getSustainAddr(MAX_INTERPOLATED_SAMPLES,FS,TARGET_NOTE,SUSTAIN_OFFSET+RELEASE_OFFSET);
    constant    SUSTAIN_END_OFFSET_ADDR         :   natural := getSustainAddr(MAX_INTERPOLATED_SAMPLES,FS,TARGET_NOTE,RELEASE_OFFSET);
    
	constant    VALUE_TO_ROUND      :   signed(50 downto 0) := "000" & X"000100000000";
    constant    STEP_VAL            :   unsigned(63 downto 0) := (to_unsigned(integer(TARGET_NOTE/BASE_NOTE),32) & X"00000000") or toUnFix( (TARGET_NOTE/BASE_NOTE),32,32);

    constant    SUSTAIN_STEP_START  :   unsigned(63 downto 0) := (to_unsigned(integer(getSustainStep(TARGET_NOTE/BASE_NOTE,SUSTAIN_START_OFFSET_ADDR)),32) & X"00000000") or toUnFix( getSustainStep(TARGET_NOTE/BASE_NOTE,SUSTAIN_START_OFFSET_ADDR) ,32,32);
    constant    SUSTAIN_STEP_END    :   unsigned(63 downto 0) := (to_unsigned(integer(getSustainStep(TARGET_NOTE/BASE_NOTE,SUSTAIN_END_OFFSET_ADDR)),32) & X"00000000") or toUnFix( getSustainStep(TARGET_NOTE/BASE_NOTE,SUSTAIN_END_OFFSET_ADDR) ,32,32);

	constant    MAX_POS_VAL  :   signed(16 downto 0) := "0" & X"7FFF";
	constant    MAX_NEG_VAL  :   signed(16 downto 0) := "1" & X"0000";
	
---------------------------	SIGNALS	--------------------------------------
	-- Registers
	signal wtinI,wtinIPlus1 : signed(15 downto 0);

	
	signal finalVal        :	signed(15 downto 0);-- 16 bits
	signal subVal          :   signed(16 downto 0);--17 bits
	signal mulVal          :   signed(49 downto 0); -- 50 bits
    
    signal roundVal        :   signed(50 downto 0); -- 51 bits
    signal addVal          :   signed(16 downto 0);
	
	signal decimalPart     :	signed(32 downto 0);-- 33 bits, msb de signo
	signal ci              :	unsigned(63 downto 0);-- 64 bits	
	
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
	

	filterRegisters :
  process (rst_n, clk,memAck,cen_in,interpolateSampleRqt)
      type states is (idle, getSample1, getSample2, interpolate, calculateNextAddr); 
      variable state: states;
      variable releaseFlag      :   std_logic;
      variable interpolatedSamplesCntr : unsigned(25 downto 0);
      variable cntr : natural range 0 to 1;
      variable currentAddr : unsigned(25 downto 0);
      variable wtout : signed(15 downto 0);
      
 begin  
    
    addr_out <= std_logic_vector(currentAddr);
    sample_out <= std_logic_vector(wtout);
	
	sample_inRqt <='0';
	if state=getSample1 or state=getSample2 then
		sample_inRqt <='1';	
	end if;
	
    if rst_n='0' then
        state := idle;
        cntr := 0;
        interpolatedSamplesCntr := (others=>'0');
        currentAddr := to_unsigned(START_ADDR,26);
        wtout := (others=>'0');
        releaseFlag :='0';
        wtinIPlus1 <= (others=>'0');
        wtinI <= (others=>'0');
		ci <=(others=>'0');
                
	elsif rising_edge(clk) then
            
            case state is
                    
                when idle =>
                    if cen_in='1' then
                        cntr := 0;
                        wtout := (others=>'0');
                        interpolatedSamplesCntr := (others=>'0');
                        currentAddr := to_unsigned(START_ADDR,26);
                        state := getSample1;
                        releaseFlag :='0';
                        ci <=(others=>'0');
                    end if;
            
                -- Recive samples
                when getSample1 =>
                    
                    if memAck='1' then 
                        currentAddr := currentAddr+1;
                        wtinI <= signed(samples_in);
                        state := getSample2;
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
                    elsif cntr=1 and interpolateSampleRqt ='1' then
                        wtout := finalVal;
                        cntr := 0;
                        ci	  <= ci+STEP_VAL; -- Calculate next step
                        state := calculateNextAddr;
                    end if;
                    
                when calculateNextAddr =>
                    -- Prepare next sample addr
                    -- Attack+Decay+Sustain phase
                    if cen_in='1'then
                        state := getSample1;
                        
                        if interpolatedSamplesCntr < to_unsigned(SUSTAIN_END_OFFSET_ADDR,26) then
                            interpolatedSamplesCntr := interpolatedSamplesCntr+1;
                            currentAddr := to_unsigned(START_ADDR,26) + ci(57 downto 32);-- Just use the integer part
                        else
                            interpolatedSamplesCntr := to_unsigned(SUSTAIN_START_OFFSET_ADDR,26);
                            currentAddr :=to_unsigned(START_ADDR,26) + SUSTAIN_STEP_START(57 downto 32);-- Just use the integer part
                            ci <= SUSTAIN_STEP_START;
                        end if;
                    
                    -- Release phase
                    else
                        if releaseFlag='1' then
                            if interpolatedSamplesCntr < to_unsigned(MAX_INTERPOLATED_SAMPLES-1,26) then
                                interpolatedSamplesCntr := interpolatedSamplesCntr+1;
                                currentAddr := to_unsigned(START_ADDR,26) + ci(57 downto 32);-- Just use the integer part
                                state := getSample1;
                            else
                                state := idle;
                            end if;
                        else
                            interpolatedSamplesCntr := to_unsigned(SUSTAIN_END_OFFSET_ADDR,26);
                            currentAddr :=to_unsigned(START_ADDR,26) + SUSTAIN_STEP_END(57 downto 32);-- Just use the integer part
                            ci <= SUSTAIN_STEP_END;
                            state := getSample1;
                            releaseFlag :='1';
						end if; --releaseFlag='1'      
                                          
                  end if;--cen_in='1'              
                end case;
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;

