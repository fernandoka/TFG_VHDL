---------------------------	CONSTANTS --------------------------------------
	constant QN				:	natural	:=	QM-WL;
	constant Q_N_M_ARITH 	:	natural := 32;
	
	constant ZEROS 			:	signed(Q_N_M_ARITH-1 downto 0) := (others=>'0');
	constant VALUE_TO_ROUND :	signed(Q_N_M_ARITH-1 downto 0) := to_signed(2**Q_N_M_ARITH,Q_N_M_ARITH);
	constant MAX_VAL_SAMPLE	:	std_logic_vector(WL-2 downto 0) := (others=>'1');
	
	constant MAX_POS_VAL	:	signed(QM+QN downto 0) := "00" & MAX_VAL_SAMPLE;
	constant MAX_NEG_VAL	:	signed(QM+QN downto 0) := "11" & not MAX_VAL_SAMPLE;
	constant STEP_VAL		:	signed(2*Q_N_M_ARITH-1 downto 0) := toFix(TARGET_NOTE/BASE_NOTE,Q_N_M_ARITH,Q_N_M_ARITH);
	
---------------------------	SIGNALS	--------------------------------------
	signal	subVal							:	signed(QM+QN downto 0); -- 17 bits
	signal	addVal, mulVal, roundVal		:	signed(Q_N_M_ARITH+QM+QN-1 downto 0); -- 48 bits
	signal	finalVal						:	signed(QM+QN-1 downto 0);-- 16 bits
	
	signal	decimalPart						:	signed(Q_N_M_ARITH-1);-- 31 bits
	signal	ci								:	signed(2*Q_N_M_ARITH-1 downto 0);-- 64 bits	
	
begin	
		
	Interpolation :
		subVal <= (wtinIPlus1(WL-1) & wtinIPlus1) - (wtinI(WL-1) & wtinI); -- Q2.15 = Q1.15+Q1.15
		
		mulVal <= decimalPart*subVal; -- Q2.47 = Q2.15+Q0.32
		
		addVal <= mulVal + (wtinI(WL-1) & wtinI & ZEROS); -- Q2.47 = Q2.47+Q2.47( (Q2.15<<Q_N_M_ARITH)), Wrap here!!  
	
		roundVal <= (addVal + VALUE_TO_ROUND); -- Wrap here!!
			
		satur:
			finalVal <= MAX_POS_VAL when roundVal(Q_N_M_ARITH+QM+QN-1 downto Q_N_M_ARITH) > MAX_POS_VAL else
						MAX_NEG_VAL when roundVal(Q_N_M_ARITH+QM+QN-1 downto Q_N_M_ARITH) < MAX_NEG_VAL else
						roundVal(Q_N_M_ARITH+QM+QN-2 downto Q_N_M_ARITH);
						
						
		decimalPart	<= ci(Q_N_M_ARITH-1 downto 0);