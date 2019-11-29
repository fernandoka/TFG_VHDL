----------------------------------------------------------------------------------
-- Create Date: 20.10.2019 16:31:27
-- AUTHOR         : Fernando Candelario
-------------------------------------------------------------------------------
-- REVISION HISTORY
-- VERSION  DATE         AUTHOR         DESCRIPTION
-- 1.0      2014-02-04   Fernando    Created      
-------------------------------------------------------------------------------

-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.my_common.all;

entity Midi_Soc is
  Generic(
		WL 	: natural;
		QM		: natural
  );
  Port (
		clk					: in std_logic;
		rst_n 				: in std_logic;
		
		-- Host side
		cen_in 				: in std_logic;
		note_in				: in std_logic(7 downto 0);
		sample_out 			: out std_logic_vector(WL-1 downto 0);
		
		-- Mem side
		samples_in 			: in std_logic_vector(WL-1 downto 0);
		addr_out			: out std_logic_vector(25 downto 0); -- The addres refers 16 bits
		readMem_out			: out std_logic; -- Signal to order a read to the ram interface
		sampleRqtOut_n		: out std_logic; -- Active low for one cycle
		memAck				: in std_logic
		);
end Midi_Soc;

architecture Behavioral of Midi_Soc is
-- Constants
	constant QN : natural := WL-QM;
	constant QM_ARITH : natural := 32;
	constant QN_ARITH : natural := 32;
	
	-- Constantes o no constantes
	constant halfStep : signed(WL-1 downto 0) := toFix(1,0594636363636363636363636363636‬, QN, QM );
	constant wholeStep : signed(WL-1 downto 0) := toFix(1,0594619061102959473490016389082‬‬, QN, QM );

-- Signals Declarations
	signal ci : signed(QN_ARITH+QM_ARITH-1 downto 0);
	signal noteAddr : unsigned(25 downto 0);
	signal subVal : signed(WL downto 0); -- WL and not WL-1 because overflow
	
	-- Cambiar valores longitud de las señales
	signal mulVal : signed(2*WL downto 0);
	signal sumVal : signed(2*WL downto 0);
	signal roundVal : signed(2*WL downto 0);
	
	signal finalVal : signed(WL-1 downto 0);
	
begin

  -- Wtout[i] = WtinI + decimalPart(ci)*(Wtin[i+1]-Wtin[i])
  Interpolation:
	subVal <= wtinIPlus1-wtinI;
	mulVal <= unsigned(ci(31 downto 0))*subVal;
	sumVal <= wtinI+mulVal;
	
  Round:
	 roundVal <= sumVal+('1'<<QM_ARITH); -- Cambiar

  -- Repasar Wrapping
  Wrapping:
	finalVal <= roundVal( QN_ARITH QN downto QM_ARITH-QM);
  
  fsm :
  process (rst_n, clk, memAck, cen_in)
    type states is (idle, getSamples, interpolate, calculateNextStep); 
    variable state: states;
	variable cntr : natural range 0 to 4;
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
			cntr := 0;
			currentAddr := 0;
      elsif rising_edge(clk) then
		
		case state is
        
        -- Wait cen_in
        when idle =>
			if cen_in='1' then
				cntr := 0;
				currentAddr := noteAddr;
				state := getWtinI;
			end if;

        -- Recive samples, stay in this state until I recive two samples
		-- I use cntr to modify the moore output w
        when getSamples =>
			
			if cntr=0 or cntr=2 then
				cntr := cntr+1;
			elsif memAck='1' then 
				currentAddr := currentAddr+1;
				if cntr=1 then
					cntr := 2;
					wtinI := signed(samples_in);
				elsif cntr=3 then
					cntr := 4;
					wtinIPlus1 := signed(samples_in);
					state := interpolate;
				end if;
			end if;

        -- Save interpolation value in wtout
        when interpolate =>			
			wtout := finalVal;
			state := calculateNextStep;
			
        when calculateNextStep =>			
			ci <= ci+cStep;
			state := calculateNextStep;
			
		end case;
      end if;
    end process;

 
-- Rom 
 
 
 
    
end Behavioral;
