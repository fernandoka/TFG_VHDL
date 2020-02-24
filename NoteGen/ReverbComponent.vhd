----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.2
-- Comments:
--      log2 function will define one more signal for block ram addr when
--      FIFO_DEPTH = 2**k, trust in synthesis tool to avoid the mapping of that signal
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
--use UNISIM.VComponents.all


entity ReverbComponent is
  Generic(	FIFO_DEPTH	:	in	natural;
			NUM_CYCLES_SAMPLE_IN	:	in	natural
	);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;
    reverbOnOff                 :   in  std_logic;  
    songOnOff               	:	in	std_logic;
    sampleRqt    				:	in	std_logic;
	sample_in	              	:	in	std_logic_vector(23 downto 0);
	sample_out              	:	out	std_logic_vector(23 downto 0)

  );
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  ReverbComponent  :   entity  is  "true";  
end ReverbComponent;

use work.my_common.all;

architecture Behavioral of ReverbComponent is
	
	signal  reverbOnOffFlag    :   boolean;
	
	signal	fifoValDividedByTwo, blockRamValOut	:	std_logic_vector(23 downto 0);	
    signal  wrBlockRam                          :   std_logic;
    signal  wrAddr, rdAddr                      :   std_logic_vector(log2(FIFO_DEPTH) downto 0);
    signal  sample_outWithReverb                :   std_logic_vector(23 downto 0);
    
begin	

    -- Multiplexor
    sample_out <= sample_outWithReverb when reverbOnOffFlag else sample_in;
        

	-- PreviousSample*0.5
	fifoValDividedByTwo <= blockRamValOut(23) & blockRamValOut(23 downto 1);
    
	sum: MyFiexedSum
	generic map(WL=>24)
	port map( rst_n =>rst_n, clk=>clk,a_in=>fifoValDividedByTwo,b_in=>sample_in,c_out=>sample_outWithReverb);


blockRam: MyBlockRam_inst
  generic map(DEPTH=>FIFO_DEPTH, Wl=> 24)
  port map(
    -- Host side
    clk     	=> clk,
    wr			=> wrBlockRam,
	wr_addr		=> wrAddr,
	rd_addr		=> rdAddr,
	data_in		=> sample_in,
	data_out	=> blockRamValOut

  );


reverbOnOffAction:
process(rst_n, clk)
begin
    if rst_n='0' then
        reverbOnOffFlag <= false;
    elsif rising_edge(clk) then
        if reverbOnOff='1' then
            reverbOnOffFlag <= not reverbOnOffFlag;
        end if;
    end if;
end process;




 syncBlockRam:
  process (rst_n, clk, songOnOff, sampleRqt, reverbOnOffFlag)
	  constant	MAX_CYCLES_DELAY	:	natural :=NUM_CYCLES_SAMPLE_IN-1;
      type states is (idle, countCycles); 
      
      variable state: states;
            
	  variable cntr	:	natural range 0 to MAX_CYCLES_DELAY;
	  variable flag :   boolean;
	  
 begin          		
	
	if rst_n='0' then
        state := idle;
        flag := false;
		cntr := 0;
		wrBlockRam <='0';
        wrAddr <=(others=>'0');
        rdAddr <=(others=>'0');	
	
	elsif rising_edge(clk) then
        wrBlockRam <='0';

		if songOnOff='0' or not reverbOnOffFlag then
          flag := false;
          wrAddr <=(others=>'0');
          rdAddr <=(others=>'0');
		else
            case state is
                when idle =>
                    if sampleRqt='1' then
						cntr := 0;
						if unsigned(wrAddr) < FIFO_DEPTH-1 then
						   wrAddr <= std_logic_vector(unsigned(wrAddr)+1);
						   if unsigned(wrAddr)=FIFO_DEPTH-2 then
                             flag := true;
                           end if;
						else						 
                           wrAddr <=(others=>'0');
						end if; 
                        
                        -- Start reading only when the buffer is full
                        if flag then
                            if unsigned(rdAddr) < FIFO_DEPTH-1 then
                               rdAddr <= std_logic_vector(unsigned(rdAddr)+1);
                            else						 
                               rdAddr <=(others=>'0');
                            end if; 
                        end if;

						
						state := countCycles;
					end if;

                when countCycles =>
					if cntr < MAX_CYCLES_DELAY then
						cntr := cntr+1;
					else
                        wrBlockRam <='1';
						state := idle;
					end if;              
			end case;
       end if;
       
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;
