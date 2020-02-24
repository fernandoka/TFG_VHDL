----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.1
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all


entity ButtonsSyncDebRiseEdge is
  Generic(	FREQ	:	in	natural);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
    btnc_i               		:	in	std_logic;
    btnu_i    					:	in	std_logic;
	btnr_i	              		:	in	std_logic;
	btnl_i	              		:	in	std_logic;

	xRise_btnc             		:	out	std_logic;
	xRise_btnu             		:	out	std_logic;
	xRise_btnr             		:	out	std_logic;
	xRise_btnl             		:	out	std_logic
	
  );
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  ButtonsSyncDebRiseEdge  :   entity  is  "true";  
end ButtonsSyncDebRiseEdge;

use work.my_common.all;

architecture Behavioral of ButtonsSyncDebRiseEdge is

signal  btncSync, btncDeb   : std_logic;
signal  btnuSync, btnuDeb   : std_logic;
signal  btnrSync, btnrDeb   : std_logic;
signal  btnlSync, btnlDeb   : std_logic;



begin	

-- BTNC
  BTNC_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnc_i, xSync => btncSync );

  BTNC_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btncSync, xDeb => btncDeb );
    
  BTNC_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btncDeb, xFall => open, xRise => xRise_btnc );

-- BTNU
  BTNU_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnu_i, xSync => btnuSync );

  BTNU_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnuSync, xDeb => btnuDeb );
    
  BTNU_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnuDeb, xFall => open, xRise => xRise_btnu );
    
-- BTNR
  BTNR_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnr_i, xSync => btnrSync );

  BTNR_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnrSync, xDeb => btnrDeb );
    
  BTNR_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnrDeb, xFall => open, xRise => xRise_btnr ); 


-- BTNL
  BTNL_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnl_i, xSync => btnlSync );

  BTNL_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnlSync, xDeb => btnlDeb );
    
  BTNL_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnlDeb, xFall => open, xRise => xRise_btnl ); 

        
end Behavioral;
