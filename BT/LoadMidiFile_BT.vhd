----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.2
-- Additional Comments: 
--		These signals follow a Q32.32 fix format:	stepVal_In					
--      											sustainStepStart_In	
--      											sustainStepEnd_In	
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


entity UniversalNoteGen is
  Generic(START_ADDR	:	in	natural);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
	startEndRecive				:	in	std_logic;
	finishFileReception			:	out	std_logic;
	memIsFull					:	out	std_logic; -- High when the last load file order fill up all the ddr memory
	
	-- BT side
	btRxD   					:	in	std_logic;  -- Información recibida desde el Bluethooth, conectada al TxD del chip RN-42 (G16)

	-- Mem side
	memWrWorking  				:   in  std_logic;
	fullFifo	    			:	in	std_logic;
	wrMemCMD	    			:	out	std_logic;
	memCmd	    				:	out	std_logic_vector(41 downto 0);
	
	
  );
-- Attributes for debug
	attribute   dont_touch    :   string;
	attribute   dont_touch  of  UniversalNoteGen  :   entity  is  "true";  
end UniversalNoteGen;

use work.my_common.all;

architecture Behavioral of UniversalNoteGen is


  signal btDataRx						: std_logic_vector (7 downto 0);
  signal btDataRdyRx, btBusy, btEmpty	: std_logic;

begin	

  btReceiver: rs232receiver
    generic map ( FREQ => 75_000, BAUDRATE => 115200 )
    port map ( rst_n => rst_n, clk => clk, dataRdy => btDataRdyRx, data => btDataRx, RxD => btRxD );


buildMemCMD :
  process (rst_n, clk,startEndRecive,btDataRdyRx)
      type states is (idle, getByte0, getByte1); 
      variable state: states;
	  
	  variable	memAddr	:	unsigned(25 downto 0);
	  variable	timeOut	:	unsigned(26 downto 0); -- Aprox 1.7s at 75Mhz
	  
 begin          		

    if rst_n='0' then
        state := idle;
		timeOut := (others=>'1');
		memAddr :=(others=>'0');
        memCmd <=(others=>'0');
		finishFileReception <='0'
		wrMemCMD <='0';
		memIsFull <='0';
		
	elsif rising_edge(clk) then 
		finishFileReception <='0';
		wrMemCMD <='0';
		
		-- This to cancel load file process
		if startEndRecive='1' and state/=idle then
			state := idle;
		else            
            case state is
                    
                when idle =>
                    if startEndRecive='1' then
						memAddr := to_unsigned(START_ADDR,25);
						timeOut := (others=>'1');
						memIsFull <='0';
						state := getByte0;  
                    end if;
				
				when getByte0 =>
					if btDataRdyRx='1' then
						memCmd(7 downto 0) <=  btDataRx;
						timeOut := (others=>'1');
						state := getByte1;
					-- Will end here if the nº of bytes of the files is an even number (par)
					elsif timeOut=0 then
						finishFileReception <='1';
						state := idle;
					else
						timeOut := timeOut-1;
                    end if;

				when getByte1 =>
					if btDataRdyRx='1' then
						memCmd(41 downto 8) <=  memAddr & btDataRx;
						wrMemCMD <='1';
						if memAddr=(others=>'1') then
							finishFileReception <='1';
							memIsFull <='1';
							state := idle;
						else
							memAddr := memAddr+1;
							timeOut := (others=>'1');
							state := getByte0
						end if;
					-- Will end here if the nº of bytes of the files an odd number (impar)
					elsif temp=0 then
						memCmd(41 downto 16) <=  memAddr; --Write one byte
						wrMemCMD <='1';
						finishFileReception <='1';
						state := idle;
					else
						timeOut := timeOut-1;
                    end if;

            
              
                end case;
		end if;-- startEndRecive='1' and state/=idle
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;
