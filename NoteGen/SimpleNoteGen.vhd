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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.my_common.all;

entity SimpleNoteGen is
generic (
    WL              :   in natural;
    FS              :   in real;
    BASE_FREQ       :   in real;
    SUSTAIN_OFFSET  :   in natural;
    RELEASE_OFFSET  :   in natural;
    START_ADDR      :   in natural;
    END_ADDR        :   in natural
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    interpolateSampleRqt    : in    std_logic; --
    sample_out              : out    std_logic_vector(WL-1 downto 0);
    
    --Mem side
    samples_in              :   in  std_logic_vector(WL-1 downto 0);
    memAck                  :   in  std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
	sample_inRqt			:	out	std_logic	--	A 1 cuando espera una nueva muestra de memoria.
  );
-- Attributes for debug
  attribute   dont_touch    :   string;
  attribute   dont_touch  of  SimpleNoteGen  :   entity  is  "true";  
end SimpleNoteGen;

architecture Behavioral of SimpleNoteGen is

    constant    SUSTAIN_START_ADDR  :   unsigned(25 downto 0) := to_unsigned(START_ADDR + getSustainAddr(END_ADDR-START_ADDR+1,FS,BASE_FREQ,SUSTAIN_OFFSET+RELEASE_OFFSET),26);
    constant    SUSTAIN_END_ADDR    :   unsigned(25 downto 0) := to_unsigned(START_ADDR + getSustainAddr(END_ADDR-START_ADDR+1,FS,BASE_FREQ,RELEASE_OFFSET),26);

begin
	
   fsm:
process (rst_n, clk,memAck,cen_in,interpolateSampleRqt)
   type states is (idle, getSample1, WaitSampleRequest); 
   variable state            :   states;
   variable releaseFlag      :   std_logic;
   variable cntr             :   unsigned(0 downto 0);
   variable currentAddr      :   unsigned(25 downto 0);
   variable nextSample       :   std_logic_vector(WL-1 downto 0);
   variable wtout            :   std_logic_vector(WL-1 downto 0);
begin  
 
 addr_out <= std_logic_vector(currentAddr);
 sample_out <= wtout;
 
 sample_inRqt <='0';
 if state=getSample1 then
	sample_inRqt <='1';	
 end if;
 
 if rst_n='0' then
     state := idle;
     cntr :=(others => '0');
     currentAddr := to_unsigned(START_ADDR,26);
     wtout := (others=>'0');
     releaseFlag :='0';
            
 elsif rising_edge(clk) then
     
         case state is
                 
             when idle =>
                 if cen_in='1' then
                     cntr :=(others => '0');
                     wtout := (others=>'0');
                     currentAddr := to_unsigned(START_ADDR,26);
                     state := getSample1;
                     releaseFlag :='0';
                 end if;
         
             -- Recive samples
             when getSample1 =>
                 if memAck='1' then 
                     nextSample := samples_in;
                     state := WaitSampleRequest;
                 end if;
         
                 
             when WaitSampleRequest =>
                 if cntr=0 and interpolateSampleRqt ='1' then
                     cntr :=cntr+1;
                 elsif cntr=1 and interpolateSampleRqt ='1' then
                     wtout := nextSample;
                     cntr :=(others => '0');                        
                     
                     -- Prepare next sample addr
                     -- Attack+Decay+Sustain phase
                     if cen_in='1' then
                         if currentAddr < SUSTAIN_END_ADDR then
                             currentAddr := currentAddr+1; 
                         else
                             currentAddr := SUSTAIN_START_ADDR;
                         end if;

                         state := getSample1;
                     
                     -- Release phase
                     else
                         if releaseFlag='1' then
                             if currentAddr<END_ADDR then
                                 currentAddr := currentAddr+1;
                                 state := getSample1;
							 else
                                 state := idle;
                             end if;  
                         else
                             currentAddr := SUSTAIN_END_ADDR;
                             releaseFlag :='1';
                             state := getSample1;
                         end if;-- releaseFlag

                     end if; --cen='1'
                 end if;--cntr=1 and interpolateSampleRqt ='1'

             end case;
       end if; --rst_n/rising_edge

end process;
        
end Behavioral;
