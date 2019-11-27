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
		readMem_out			: out std_logic;
		sampleRqtOut_n		: out std_logic -- Active low for one cycle
		
		);
end Midi_Soc;

architecture Behavioral of Midi_Soc is
-- Constants
	constant QN : natural := WIDTH-QM;
	-- Constantes o no constantes
	constant halfStep : signed(WL-1 downto 0) := toFix(1,0594636363636363636363636363636‬, QN, QM );
	constant wholeStep : signed(WL-1 downto 0) := toFix(1,0594619061102959473490016389082‬‬, QN, QM );

-- Signals Declarations



begin

  fsm :
  process (rst_n, clk)
  
  begin
      if rst_n='0' then

      elsif rising_edge(clk) then

      end if;
    end process;

 
 
 
 
 
    
end Behavioral;
