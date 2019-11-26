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
		WIDTH 	: natural
  );
  Port (
		clk			: in std_logic;
		rst_n 		: in std_logic;
		cen 		: in std_logic;
		note		: in std_logic(7 downto 0);
		
		samples_in 	: in std_logic_vector(WIDTH*2-1 downto 0); -- Recibe 2 muestras
		addr_out	: out std_logic_vector(25 downto 0); -- Direcciona 16 bits
		sample_out 	: out std_logic_vector(WIDTH-1 downto 0);
		
	);
end Midi_Soc;

architecture Behavioral of Midi_Soc is
----------------------------------------------------------------------------------
-- Signals Declarations
---------------------------------------------------------------------------------- 



begin



 
    
end Behavioral;
