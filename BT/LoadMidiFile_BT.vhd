----------------------------------------------------------------------------------
-- Company: fdi Universidad Complutense de Madrid, Spain
-- Engineer: Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.2
-- Additional Comments: 	
--      The use of a full buffer signal (for the writings of the mem CMDs) have no sense, 
--      Bluetooth too slow
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


entity LoadMidiFile_BT is
  Generic(START_ADDR	:	in	natural);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
	startEndRecive				:	in	std_logic;
	finishFileReception			:	out	std_logic;
	memIsFull					:	out	std_logic; -- High when the last load file order fill up all the ddr memory
	
	-- BT side
	btRxD   					:	in	std_logic;  -- InformaciÃ³n recibida desde el Bluethooth, conectada al TxD del chip RN-42 (G16)

	-- Mem side
	memWrWorking  				:   in  std_logic;
	wrMemCMD	    			:	out	std_logic;
	memCmd	    				:	out	std_logic_vector(41 downto 0)
	
	
  );
-- Attributes for debug
	attribute   dont_touch    :   string;
	attribute   dont_touch  of  LoadMidiFile_BT  :   entity  is  "true";  
end LoadMidiFile_BT;

use work.my_common.all;

architecture Behavioral of LoadMidiFile_BT is


  signal btDataRx						: std_logic_vector (7 downto 0);
  signal btDataRdyRx, btBusy, btEmpty	: std_logic;

begin	

  btReceiver: rs232receiver
    generic map ( FREQ => 75_000, BAUDRATE => 115200 )
    port map ( rst_n => rst_n, clk => clk, dataRdy => btDataRdyRx, data => btDataRx, RxD => btRxD );


buildMemCMD :
  process (rst_n, clk,startEndRecive,btDataRdyRx,memWrWorking)
      constant  MAX_ADDR    :   unsigned(25 downto 0) := (others=>'1');
      type states is (idle, getByte0, getByte1, waitMemWrite); 
      variable state: states;
	  
	  variable	memAddr	:	unsigned(25 downto 0);
	  variable	timeOut	:	unsigned(26 downto 0); -- Aprox 1.7s at 75Mhz
	  variable  flag    :   boolean;
	     
 begin          		

    if rst_n='0' then
        state := idle;
		timeOut := (others=>'1');
		memAddr :=(others=>'0');
		flag  := false;
        memCmd <=(others=>'0');
		finishFileReception <='0';
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
						memAddr := to_unsigned(START_ADDR,26);
						timeOut := (others=>'1');
						flag := false;
						memIsFull <='0';
						state := getByte0;  
                    end if;
				
				when getByte0 =>
					if btDataRdyRx='1' then
                        flag := true;
						memCmd(7 downto 0) <=  btDataRx;
						timeOut := (others=>'1');
						state := getByte1;
					-- Will end here if the nÂº of bytes of the files is an even number (par)
					elsif timeOut=0 then
						state := waitMemWrite;
					elsif flag then
						timeOut := timeOut-1;
                    end if;

				when getByte1 =>
					if btDataRdyRx='1' then
						memCmd(41 downto 8) <=  std_logic_vector(memAddr) & btDataRx;
						wrMemCMD <='1';
						if memAddr=MAX_ADDR then
							memIsFull <='1';
							state := waitMemWrite;
						else
							memAddr := memAddr+1;
							timeOut := (others=>'1');
							state := getByte0;
						end if;
					-- Will end here if the nÂº of bytes of the files is an odd number (impar)
					elsif timeOut=0 then
						memCmd(41 downto 16) <=  std_logic_vector(memAddr); --Write one byte
						wrMemCMD <='1';
						state := waitMemWrite;
					else
						timeOut := timeOut-1;
                    end if;
                    
                when waitMemWrite =>
                    if memWrWorking='0' then
                        finishFileReception <='1';
                        state := idle;
                    end if;
                end case;
				
		end if;-- startEndRecive='1' and state/=idle
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;
