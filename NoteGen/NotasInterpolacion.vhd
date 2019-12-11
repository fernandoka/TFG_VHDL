	constant Q_N_M_ARITH : natural := 32;

	constant ZEROS : signed(Q_N_M_ARITH-1 downto 0) := (others=>'0');
	
	constant VALUE_TO_ROUND : signed(Q_N_M_ARITH-1 downto 0) := ;
	
	
	
	Interpolation :
		subVal <= (wtinIPlus1(WL-1) & wtinIPlus1) - (wtinI(WL-1) & wtinI);
		
		mulVal <= decimalPart*subVal; -- Q2.47 = Q2.15+Q0.32
		
		wrap:
			addVal <= mulVal + (wtinI(WL-1) & wtinI & ZEROS); -- Q2.47 = Q2.47+Q2.47( (Q2.15<<Q_N_M_ARITH))  
		
		round:
			roundVal <= addVal + VALUE_TO_ROUND;