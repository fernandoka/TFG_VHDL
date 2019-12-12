----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.1
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

entity SimpleNoteGen is
generic (
    WL : natural;
    START_ADDR: natural;
    END_ADDR: natural
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
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
    readMem_out             :   out std_logic
  );
end SimpleNoteGen;

architecture Behavioral of SimpleNoteGen is

begin
	
   fsm:
  process (rst_n, clk)
      type states is (idle, getSample1, WaitSampleRequest, calculateNextStep); 
      variable state: states;
      variable cntr : unsigned(3 downto 0);
      variable currentAddr : natural range START_ADDR to END_ADDR;
      variable nextSample   :   std_logic_vector(WL-1 downto 0);
      variable wtout : std_logic_vector(WL-1 downto 0);
  begin  
    
    addr_out <= (others=>'0');
    addr_out <= std_logic_vector(to_unsigned(currentAddr,26));
    sample_out <= wtout;

    if rst_n='0' then
        state := idle;
        cntr :=(others => '0');
        currentAddr := START_ADDR;
        wtout := (others=>'0');
        readMem_out <= '1';
                
	elsif rising_edge(clk) then
        readMem_out <= '1';
            
        if cen_in='0' then
            state := idle;
        else
            case state is
                    
                when idle =>
                    if cen_in='1' then
                        cntr :=(others => '0');
                        wtout := (others=>'0');
                        currentAddr := START_ADDR;
                        state := getSample1;
                        -- Prepare read
                        readMem_out <= '0';
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
                        currentAddr := currentAddr+1; -- Prepare next sample addr
                        state := calculateNextStep;
                    end if;
                    
                when calculateNextStep =>
                        cntr :=(others => '0');
                        if currentAddr >= END_ADDR then 
                            currentAddr := START_ADDR; -- This because is a test
                        end if;
                        state := getSample1;
                        -- Prepare read
                        readMem_out <= '0';
            
                end case;
          end if; --If cen_in='0'
    end if; 
  end process;
        
end Behavioral;
