----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: NotesGenerator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.5
-- Additional Comments:
--		Not completly generic component, the pipelined sum and the NotesGenerators 
--		have to be done by hand
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

entity NotesGenerator is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen             :   in  std_logic;
		emtyCmdBuffer	:	in std_logic;	
		cmdKeyboard		:	in std_logic_vector(9 downto 0);
		keyboard_ack	:	out	std_logic;
        
        --IIS side
        sampleRqt       :   in  std_logic;
        sampleOut       :   out std_logic_vector(15 downto 0);
        
        
        -- Mem side
        mem_sampleIn    :   in  std_logic_vector(15 downto 0);
        mem_ack         :   in  std_logic;
        mem_addrOut     :   out std_logic_vector(25 downto 0);
        mem_readOut     :   out std_logic
  
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  NotesGenerator  :   entity  is  "true";
    
end NotesGenerator;

use work.my_common.all;

architecture Behavioral of NotesGenerator is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
    type    samplesOut  is array(0 to NUM_NOTES-1) of std_logic_vector(15 downto 0);
    type    addrOut  is array(0 to NUM_NOTES-1) of std_logic_vector(25 downto 0);
    type    sumStage0   is array( 0 to (NUM_NOTES/2)-1 ) of std_logic_vector(15 downto 0);
    type    sumStage1   is array( 0 to (NUM_NOTES/4)-1 ) of std_logic_vector(15 downto 0);
    type    sumStage2   is array( 0 to (NUM_NOTES/8)-1 ) of std_logic_vector(15 downto 0);
    type    sumStage3   is array( 0 to (NUM_NOTES/16)-1 ) of std_logic_vector(15 downto 0);
    type    sumStage4   is array( 0 to 2) of std_logic_vector(15 downto 0);

	
    type    iniData  is array(0 to 59) of natural;
    type    freq is array(0 to 87) of real;
	type	maxInterpolatedSamplesPerNote_t is array(0 to 57) of natural;
	type	offset_t is array(0 to 87) of natural;
	
	
----------------------------------------------------------------------------------
-- CONSTANTS DECLARATIONS
----------------------------------------------------------------------------------         
    constant    SAMPLES_PER_WAVETABLE   :   natural :=  189644;
    constant    FS                      :   real    :=  48800.0; -- frecuencia de muestreo, Hz
    
    constant    iniVals :   iniData :=(
		  0=>0,1=>SAMPLES_PER_WAVETABLE-1,      --A0

        2=>SAMPLES_PER_WAVETABLE,3=>SAMPLES_PER_WAVETABLE*2-1,      	--C1
        4=>SAMPLES_PER_WAVETABLE*2,5=>SAMPLES_PER_WAVETABLE*3-1,      --D#1
        6=>SAMPLES_PER_WAVETABLE*3,7=>SAMPLES_PER_WAVETABLE*4-1,      --F#1        
        8=>SAMPLES_PER_WAVETABLE*4,9=>SAMPLES_PER_WAVETABLE*5-1,      --A1

        10=>SAMPLES_PER_WAVETABLE*5,11=>SAMPLES_PER_WAVETABLE*6-1,    --C2    
        12=>SAMPLES_PER_WAVETABLE*6,13=>SAMPLES_PER_WAVETABLE*7-1,    --D#2
        14=>SAMPLES_PER_WAVETABLE*7,15=>SAMPLES_PER_WAVETABLE*8-1,     --F#2               
        16=>SAMPLES_PER_WAVETABLE*8,17=>SAMPLES_PER_WAVETABLE*9-1,    --A2
		
        18=>SAMPLES_PER_WAVETABLE*9,19=>SAMPLES_PER_WAVETABLE*10-1,    --C3
        20=>SAMPLES_PER_WAVETABLE*10,21=>SAMPLES_PER_WAVETABLE*11-1,   --D#3
        22=>SAMPLES_PER_WAVETABLE*11,23=>SAMPLES_PER_WAVETABLE*12-1,   --F#3        
        24=>SAMPLES_PER_WAVETABLE*12,25=>SAMPLES_PER_WAVETABLE*13-1,   --A3


		26=>SAMPLES_PER_WAVETABLE*13,27=>SAMPLES_PER_WAVETABLE*14-1,    --C4
		28=>SAMPLES_PER_WAVETABLE*14,29=>SAMPLES_PER_WAVETABLE*15-1,    --D#4
		30=>SAMPLES_PER_WAVETABLE*15,31=>SAMPLES_PER_WAVETABLE*16-1,    --F#4
		32=>SAMPLES_PER_WAVETABLE*16,33=>SAMPLES_PER_WAVETABLE*17-1,    --A4

		34=>SAMPLES_PER_WAVETABLE*17,35=>SAMPLES_PER_WAVETABLE*18-1,    --C5
		36=>SAMPLES_PER_WAVETABLE*18,37=>SAMPLES_PER_WAVETABLE*19-1,    --D#5    
		38=>SAMPLES_PER_WAVETABLE*19,39=>SAMPLES_PER_WAVETABLE*20-1,    --F#5
		40=>SAMPLES_PER_WAVETABLE*20,41=>SAMPLES_PER_WAVETABLE*21-1,     --A5

		
        42=>SAMPLES_PER_WAVETABLE*21,43=>SAMPLES_PER_WAVETABLE*22-1,    --C6
        44=>SAMPLES_PER_WAVETABLE*22,45=>SAMPLES_PER_WAVETABLE*23-1,    --D#6
        46=>SAMPLES_PER_WAVETABLE*23,47=>SAMPLES_PER_WAVETABLE*24-1,    --F#6        
        48=>SAMPLES_PER_WAVETABLE*24,49=>SAMPLES_PER_WAVETABLE*25-1,    --A6

        50=>SAMPLES_PER_WAVETABLE*25,51=>SAMPLES_PER_WAVETABLE*26-1,    --C7    
        52=>SAMPLES_PER_WAVETABLE*26,53=>SAMPLES_PER_WAVETABLE*27-1,    --D#7
        54=>SAMPLES_PER_WAVETABLE*27,55=>SAMPLES_PER_WAVETABLE*28-1,     --F#7               
        56=>SAMPLES_PER_WAVETABLE*28,57=>SAMPLES_PER_WAVETABLE*29-1,    --A7
		
        58=>SAMPLES_PER_WAVETABLE*29,59=>SAMPLES_PER_WAVETABLE*30-1    --C8

    );
    
   constant    iniFreq :   freq :=(
		0=>27.5, 1=>29.1353, 2=>30.8677,	  	  -- A0, A#0, B0
   
        3=>32.7032, 4=>34.6479, 5=>36.7081,     -- C1, C#1, D1
        6=>38.8909, 7=>41.2035, 8=>43.6536,     -- D#1, E1, F1 
        9=>46.2493, 10=>48.9995, 11=>51.9130,   -- F#1, G1, G#1
        12=>55.0000, 13=>58.2705, 14=>61.7354,  -- A1, A#1, B1

        15=>65.4064, 16=>69.2957, 17=>73.4162,  -- C2, C#2, D2
        18=>77.7817, 19=>82.4069, 20=>87.3071,   -- D#2, E2, F2 
        21=>92.4986, 22=>97.9989, 23=>103.826,  -- F#2, G2, G#2
        24=>110.000, 25=>116.541, 26=>123.471,  -- A2, A#2, B2

        27=>130.813, 28=>138.591, 29=>146.832,     -- C3, C#3, D3
        30=>155.563, 31=>16.814, 32=>174.614,     -- D#3, E3, F3 
        33=>184.997, 34=>195.998, 35=>207.652,   	 -- F#3, G3, G#3
        36=>220.000, 37=>233.082, 38=>246.942,  	 -- A3, A#3, B3	
		
		39=>261.626, 40=>277.183, 41=>293.665,     ---- C4, C#4, D4
        42=>311.127, 43=>329.628, 44=>349.228,     ---- D#4, E4, F4 
        45=>369.994, 46=>391.995, 47=>415.305,     ---- F#4, G4, G#4
        48=>440.000, 49=>466.164, 50=>493.883,     ---- A4, A#4, B4

        51=>523.251, 52=>554.365, 53=>587.330,  	 ---- C5, C#5, D5
        54=>622.254, 55=>659.255, 56=>698.456,  	 ---- D#5, E5, F5 
        57=>739.989, 58=>783.991, 59=>830.609,     ---- F#5, G5, G#5
        60=>880.000, 61=>932.328, 62=>987.767,     ---- A5, A#5, B5

        63=>1046.50, 64=>1108.73, 65=>1174.66,  	 ---- C6, C#6, D6
        66=>1244.51, 67=>1318.51, 68=>1396.91,  	 ---- D#6, E6, F6 
        69=>1479.98, 70=>1567.98, 71=>1661.22,     ---- F#6, G6, G#6
        72=>1760.00, 73=>1864.66, 74=>1975.53,     ---- A6, A#6, B6

        75=>2093.00, 76=>2217.46, 77=>2349.32,  	 ---- C7, C#7, D7
        78=>2489.02, 79=>2637.02, 80=>2793.83,  	 ---- D#7, E7, F7 
        81=>2959.96, 82=>3135.96, 83=>3322.44,     ---- F#7, G7, G#7
        84=>3520.00, 85=>3729.31, 86=>3951.07,     ---- A7, A#7, B7

        87=>4186.01  	 							 ---- C8
    );

   constant    MAX_INTERPOLATED_SAMPLES_PER_NOTE :   maxInterpolatedSamplesPerNote_t :=(
		  0=>integer( (real(SAMPLES_PER_WAVETABLE)/(29.1353/27.5))+0.5 ), 1=>integer( (real(SAMPLES_PER_WAVETABLE)/(30.8677/27.5))+0.5 ), -- A#0, B0 
		  
		  2=>integer( (real(SAMPLES_PER_WAVETABLE)/(34.6479/32.7032))+0.5 ), 3=>integer( (real(SAMPLES_PER_WAVETABLE)/(36.7081/32.7032))+0.5 ), -- C#1, D1
		  4=>integer( (real(SAMPLES_PER_WAVETABLE)/(41.2035/38.8909))+0.5 ), 5=>integer( (real(SAMPLES_PER_WAVETABLE)/(43.6536/38.8909))+0.5 ), -- E1, F1
		  6=>integer( (real(SAMPLES_PER_WAVETABLE)/(48.9995/46.2493))+0.5 ), 7=>integer( (real(SAMPLES_PER_WAVETABLE)/(51.9130/46.2493))+0.5 ), -- G1, G#1
		  8=>integer( (real(SAMPLES_PER_WAVETABLE)/(58.2705/55.0000))+0.5 ), 9=>integer( (real(SAMPLES_PER_WAVETABLE)/(61.7354/55.0000))+0.5 ), -- A#1, B1
																			 
		  10=>integer( (real(SAMPLES_PER_WAVETABLE)/(69.2957/65.4064))+0.5 ), 11=>integer( (real(SAMPLES_PER_WAVETABLE)/(73.4162/65.4064))+0.5 ), -- C#2, D2
		  12=>integer( (real(SAMPLES_PER_WAVETABLE)/(82.4069/77.7817))+0.5 ), 13=>integer( (real(SAMPLES_PER_WAVETABLE)/(87.3071/77.7817))+0.5 ), -- E2, F2
		  14=>integer( (real(SAMPLES_PER_WAVETABLE)/(97.9989/92.4986))+0.5 ), 15=>integer( (real(SAMPLES_PER_WAVETABLE)/(103.826/92.4986))+0.5 ), -- G2, G#2
		  16=>integer( (real(SAMPLES_PER_WAVETABLE)/(116.541/110.000))+0.5 ), 17=>integer( (real(SAMPLES_PER_WAVETABLE)/(123.471/110.000))+0.5 ), -- A#2, B2
																			 
		  18=>integer( (real(SAMPLES_PER_WAVETABLE)/(138.591/130.813))+0.5 ), 19=>integer( (real(SAMPLES_PER_WAVETABLE)/(146.832/130.813))+0.5 ), -- C#3, D3
		  20=>integer( (real(SAMPLES_PER_WAVETABLE)/(164.814/155.563))+0.5 ), 21=>integer( (real(SAMPLES_PER_WAVETABLE)/(174.614/155.563))+0.5 ), -- E3, F3
		  22=>integer( (real(SAMPLES_PER_WAVETABLE)/(195.998/184.997))+0.5 ), 23=>integer( (real(SAMPLES_PER_WAVETABLE)/(207.652/184.997))+0.5 ), -- G3, G#3
		  24=>integer( (real(SAMPLES_PER_WAVETABLE)/(233.082/220.000))+0.5 ), 25=>integer( (real(SAMPLES_PER_WAVETABLE)/(246.942/220.000))+0.5 ), -- A#3, B3
																			 
		  26=>integer( (real(SAMPLES_PER_WAVETABLE)/(277.183/261.626))+0.5 ), 27=>integer( (real(SAMPLES_PER_WAVETABLE)/(293.665/261.626))+0.5 ), -- C#4, D4
		  28=>integer( (real(SAMPLES_PER_WAVETABLE)/(329.628/311.127))+0.5 ), 29=>integer( (real(SAMPLES_PER_WAVETABLE)/(349.228/311.127))+0.5 ), -- E4, F4
		  30=>integer( (real(SAMPLES_PER_WAVETABLE)/(391.995/369.994))+0.5 ), 31=>integer( (real(SAMPLES_PER_WAVETABLE)/(415.305/369.994))+0.5 ), -- G4, G#4
		  32=>integer( (real(SAMPLES_PER_WAVETABLE)/(466.164/440.000))+0.5 ), 33=>integer( (real(SAMPLES_PER_WAVETABLE)/(493.883/440.000))+0.5 ), -- A#4, B4
																			 
		  34=>integer( (real(SAMPLES_PER_WAVETABLE)/(554.365/523.251))+0.5 ), 35=>integer( (real(SAMPLES_PER_WAVETABLE)/(587.330/523.251))+0.5 ), -- C#5, D5
		  36=>integer( (real(SAMPLES_PER_WAVETABLE)/(659.255/622.254))+0.5 ), 37=>integer( (real(SAMPLES_PER_WAVETABLE)/(698.456/622.254))+0.5 ), -- E5, F5
		  38=>integer( (real(SAMPLES_PER_WAVETABLE)/(783.991/739.989))+0.5 ), 39=>integer( (real(SAMPLES_PER_WAVETABLE)/(830.609/739.989))+0.5 ), -- G5, G#5
		  40=>integer( (real(SAMPLES_PER_WAVETABLE)/(932.328/880.000))+0.5 ), 41=>integer( (real(SAMPLES_PER_WAVETABLE)/(987.767/880.000))+0.5 ), -- A#5, B5
																			 
		  42=>integer( (real(SAMPLES_PER_WAVETABLE)/(1108.73/1046.50))+0.5 ), 43=>integer( (real(SAMPLES_PER_WAVETABLE)/(1174.66/1046.50))+0.5 ), -- C#6, D6
		  44=>integer( (real(SAMPLES_PER_WAVETABLE)/(1318.51/1244.51))+0.5 ), 45=>integer( (real(SAMPLES_PER_WAVETABLE)/(1396.91/1244.51))+0.5 ), -- E6, F6
		  46=>integer( (real(SAMPLES_PER_WAVETABLE)/(1567.98/1479.98))+0.5 ), 47=>integer( (real(SAMPLES_PER_WAVETABLE)/(1661.22/1479.98))+0.5 ), -- G6, G#6
		  48=>integer( (real(SAMPLES_PER_WAVETABLE)/(1864.66/1760.00))+0.5 ), 49=>integer( (real(SAMPLES_PER_WAVETABLE)/(1975.53/1760.00))+0.5 ), -- A#6, B6
																			 
		  50=>integer( (real(SAMPLES_PER_WAVETABLE)/(2217.46/2093.00))+0.5 ), 51=>integer( (real(SAMPLES_PER_WAVETABLE)/(2349.32/2093.00))+0.5 ), -- C#7, D7
		  52=>integer( (real(SAMPLES_PER_WAVETABLE)/(2637.02/2489.02))+0.5 ), 53=>integer( (real(SAMPLES_PER_WAVETABLE)/(2793.83/2489.02))+0.5 ), -- E7, F7
		  54=>integer( (real(SAMPLES_PER_WAVETABLE)/(3135.96/2959.96))+0.5 ), 55=>integer( (real(SAMPLES_PER_WAVETABLE)/(3322.44/2959.96))+0.5 ), -- G7, G#7
		  56=>integer( (real(SAMPLES_PER_WAVETABLE)/(3729.31/3520.00))+0.5 ), 57=>integer( (real(SAMPLES_PER_WAVETABLE)/(3951.07/3520.00))+0.5 ), -- A#7, B7		  

    );

	-------------------------------------------------
	-- Offset values to configure the sustain loop --
	-------------------------------------------------

   constant    SUSTAIN_OFFSET :   offset_t :=(
		0=>15,  1=>9,   2=>9, 	   -- A0, A#0, B0
   
        3=>15, 	4=>9,  5=>9,     -- C1, C#1, D1
        6=>15, 	7=>9,  8=>9,     -- D#1, E1, F1 
        9=>15, 	10=>9, 11=>9,   -- F#1, G1, G#1
        12=>15, 13=>9, 14=>9,  -- A1, A#1, B1

        15=>15, 16=>9, 17=>9,  -- C2, C#2, D2
        18=>15, 19=>9, 20=>9,   -- D#2, E2, F2 
        21=>15, 22=>9, 23=>9,  -- F#2, G2, G#2
        24=>15, 25=>9, 26=>9,  -- A2, A#2, B2

        27=>15, 28=>9, 29=>9,     -- C3, C#3, D3
        30=>15, 31=>9, 32=>9,     -- D#3, E3, F3 
        33=>15, 34=>9, 35=>9,   	 -- F#3, G3, G#3
        36=>15, 37=>9, 38=>9,  	 -- A3, A#3, B3
			
	    39=>12, 40=>12, 41=>9,     ---- C4, C#4, D4
        42=>12, 43=>5, 44=>12,     ---- D#4, E4, F4 
        45=>12, 46=>12, 47=>12,     ---- F#4, G4, G#4
        48=>12, 49=>12, 50=>12,     ---- A4, A#4, B4

        51=>12, 52=>12, 53=>8,  	 ---- C5, C#5, D5
        54=>12, 55=>12, 56=>12,  	 ---- D#5, E5, F5 
        57=>15, 58=>9, 59=>9,     ---- F#5, G5, G#5
        60=>15, 61=>9, 62=>9,     ---- A5, A#5, B5

        63=>15, 64=>9, 65=>9,  	 ---- C6, C#6, D6
        66=>15, 67=>9, 68=>9,  	 ---- D#6, E6, F6 
        69=>15, 70=>9, 71=>9,     ---- F#6, G6, G#6
        72=>15, 73=>9, 74=>9,     ---- A6, A#6, B6

        75=>15, 76=>9, 77=>9,  	 ---- C7, C#7, D7
        78=>15, 79=>9, 80=>9,  	 ---- D#7, E7, F7 
        81=>15, 82=>9, 83=>9,     ---- F#7, G7, G#7
        84=>15, 85=>9, 86=>9,     ---- A7, A#7, B7

        87=>15  	 			  ---- C8
    );	
    

   constant    RELEASE_OFFSET :   offset_t :=(
		0=>10, 1=>10, 2=>10, 	   -- A0, A#0, B0
			
        3=>10, 	4=>10, 	5=>10,     -- C1, C#1, D1
        6=>10, 	7=>10, 	8=>10,     -- D#1, E1, F1 
        9=>10, 	10=>10, 11=>10,   -- F#1, G1, G#1
        12=>10,	13=>10, 14=>10,  -- A1, A#1, B1

        15=>10, 16=>10, 17=>10,  -- C2, C#2, D2
        18=>10, 19=>10, 20=>10,   -- D#2, E2, F2 
        21=>10, 22=>10, 23=>10,  -- F#2, G2, G#2
        24=>10, 25=>10, 26=>10,  -- A2, A#2, B2
							
        27=>10, 28=>10, 29=>10,     -- C3, C#3, D3
        30=>10, 31=>10, 32=>10,     -- D#3, E3, F3 
        33=>10, 34=>10, 35=>10,   	 -- F#3, G3, G#3
        36=>10, 37=>10, 38=>10,  	 -- A3, A#3, B3
							
	    39=>10, 40=>10, 41=>10,     ---- C4, C#4, D4
        42=>10, 43=>10, 44=>10,     ---- D#4, E4, F4 
        45=>10, 46=>10, 47=>10,     ---- F#4, G4, G#4
        48=>10, 49=>10, 50=>10,     ---- A4, A#4, B4
							
        51=>10, 52=>10, 53=>10,  	 ---- C5, C#5, D5
        54=>10, 55=>10, 56=>10,  	 ---- D#5, E5, F5 
        57=>10, 58=>10, 59=>10,     ---- F#5, G5, G#5
        60=>10, 61=>10, 62=>10,     ---- A5, A#5, B5
							
        63=>10, 64=>10, 65=>10,  	 ---- C6, C#6, D6
        66=>10, 67=>10, 68=>10,  	 ---- D#6, E6, F6 
        69=>10, 70=>10, 71=>10,     ---- F#6, G6, G#6
        72=>10, 73=>10, 74=>10,     ---- A6, A#6, B6
							
        75=>10, 76=>10, 77=>10,  	 ---- C7, C#7, D7
        78=>10, 79=>10, 80=>10,  	 ---- D#7, E7, F7 
        81=>10, 82=>10, 83=>10,     ---- F#7, G7, G#7
        84=>10, 85=>10, 86=>10,     ---- A7, A#7, B7

        87=>10  	 			  ---- C8
    );	
    
----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- Registers
    signal  notesGen_samplesOut         :   samplesOut;
             
    signal  notesEnable                 :   std_logic_vector(NUM_NOTES-1 downto 0);
    signal  muxSampleInRqt, muxMemAck   :   std_logic_vector(NUM_NOTES-1 downto 0);
    
    signal  notesGen_addrOut            :   addrOut;
        
    signal  sampleOutAux_S0             :   sumStage0;
    signal  sampleOutAux_S1             :   sumStage1;
    signal  sampleOutAux_S2             :   sumStage2;
    signal  sampleOutAux_S3             :   sumStage3;
    signal  sampleOutAux_S4             :   sumStage4;
    
    signal  sampleOutAux_S5, sampleOutAux_S6    :   std_logic_vector(15 downto 0);

begin
             
NotesEnableGen:
for i in 0 to (NUM_NOTES-1) generate
    notesEnable(i) <= notes_on(i) and cen;
end generate;

	maxSamples_In				:	in	std_logic_vector(25 downto 0);	-- (TARGET_NOTE/BASE_NOTE)*SAMPLES_PER_WAVETABLE
	stepVal_In					:	in	std_logic_vector(63 downto 0);  -- If is a simple note, stepVal_In=1.0 
	sustainStepStart_In			:	in	std_logic_vector(63 downto 0);	-- If is a simple note, sustainStepStart_In=1.0
	sustainStepEnd_In			:	in	std_logic_vector(63 downto 0);	-- If is a simple note, sustainStepEnd_In=1.0
	

-- Hexadecimal values of the notes
-- Decode note value	
	startAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			startAddr_In <=
				
				to_unsigned(SAMPLES_PER_WAVETABLE,26)		when X"18" | X"19" | X"1A", 	-- C1, C#1, D1
				to_unsigned(SAMPLES_PER_WAVETABLE*2,26)		when X"1B" | X"1C" | X"1D", -- D#1, E1, F1
				to_unsigned(SAMPLES_PER_WAVETABLE*3,26)		when X"1E" | X"1F" | X"20", -- F#1, G1, G#1
				to_unsigned(SAMPLES_PER_WAVETABLE*4,26)		when X"21" | X"22" | X"23", -- A1, A#1, B1
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*5,26)		when X"24" | X"25" | X"26", 	-- C2, C#2, D2
				to_unsigned(SAMPLES_PER_WAVETABLE*6,26)		when X"27" | X"28" | X"29", -- D#2, E2, F2
				to_unsigned(SAMPLES_PER_WAVETABLE*7,26)		when X"2A" | X"2B" | X"2C", -- F#2, G2, G#2
				to_unsigned(SAMPLES_PER_WAVETABLE*8,26)		when X"2D" | X"2E" | X"2F", -- A2, A#2, B2
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*9,26)		when X"30" | X"31" | X"32", 	-- C3, C#3, D3
				to_unsigned(SAMPLES_PER_WAVETABLE*10,26)	when X"33" | X"34" | X"35", -- D#3, E3, F3
				to_unsigned(SAMPLES_PER_WAVETABLE*11,26)	when X"36" | X"37" | X"38", -- F#3, G3, G#3
				to_unsigned(SAMPLES_PER_WAVETABLE*12,26)	when X"39" | X"3A" | X"3B", -- A3, A#3, B3
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*13,26)	when X"3C" | X"3D" | X"3E", 	-- C4, C#4, D4
				to_unsigned(SAMPLES_PER_WAVETABLE*14,26)	when X"3F" | X"40" | X"41", -- D#4, E4, F4
				to_unsigned(SAMPLES_PER_WAVETABLE*15,26)	when X"42" | X"43" | X"44", -- F#4, G4, G#4
				to_unsigned(SAMPLES_PER_WAVETABLE*16,26)	when X"45" | X"46" | X"47", -- A4, A#4, B4
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*17,26)	when X"48" | X"49" | X"4A", 	-- C5, C#5, D5
				to_unsigned(SAMPLES_PER_WAVETABLE*18,26)	when X"4B" | X"4C" | X"4D", -- D#5, E5, F5
				to_unsigned(SAMPLES_PER_WAVETABLE*19,26)	when X"4E" | X"4F" | X"50", -- F#5, G5, G#5
				to_unsigned(SAMPLES_PER_WAVETABLE*20,26)	when X"51" | X"52" | X"53", -- A5, A#5, B5
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*21,26)	when X"54" | X"55" | X"56", 	-- C6, C#6, D6
				to_unsigned(SAMPLES_PER_WAVETABLE*22,26)	when X"57" | X"58" | X"59", -- D#6, E6, F6
				to_unsigned(SAMPLES_PER_WAVETABLE*23,26)	when X"5A" | X"5B" | X"5C", -- F#6, G6, G#6
				to_unsigned(SAMPLES_PER_WAVETABLE*24,26)	when X"5D" | X"5E" | X"5F", -- A6, A#6, B6
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*25,26)	when X"60" | X"61" | X"62", 	-- C7, C#7, D7
				to_unsigned(SAMPLES_PER_WAVETABLE*26,26)	when X"63" | X"64" | X"65", -- D#7, E7, F7
				to_unsigned(SAMPLES_PER_WAVETABLE*27,26)	when X"66" | X"67" | X"68", -- F#7, G7, G#7
				to_unsigned(SAMPLES_PER_WAVETABLE*28,26)	when X"69" | X"6A" | X"6B", -- A7, A#7, B7
				
				to_unsigned(SAMPLES_PER_WAVETABLE*29,26)	when X"6C"  -- C8
				
				to_unsigned(0,26) when others;  -- when X"15" | X"16" | X"17", -- A0, A#0, B0





	sustainStartOffsetAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainStartOffsetAddr_In <=
			
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,27.5,SUSTAIN_OFFSET(0)+RELEASE_OFFSET(0)),26)						when X"15", -- A0 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),FS,29.1353,SUSTAIN_OFFSET(1)+RELEASE_OFFSET(1)),26) 	when X"16", -- A#0
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),FS,30.8677,SUSTAIN_OFFSET(2)+RELEASE_OFFSET(2)),26) 	when X"17", -- B0
																																				  
				-- Octave 1	                                                                                                                    
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,32.7032,SUSTAIN_OFFSET(3)+RELEASE_OFFSET(3)),26)					when X"18", -- C1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),FS,34.6479,SUSTAIN_OFFSET(4)+RELEASE_OFFSET(4)),26) 	when X"19", -- C#1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),FS,36.7081,SUSTAIN_OFFSET(5)+RELEASE_OFFSET(5)),26) 	when X"1A", -- D1
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,38.8909,SUSTAIN_OFFSET(6)+RELEASE_OFFSET(6)),26)					when X"1B", -- D#1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),FS,41.2035,SUSTAIN_OFFSET(7)+RELEASE_OFFSET(7)),26) 	when X"1C", -- E1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),FS,43.6536,SUSTAIN_OFFSET(8)+RELEASE_OFFSET(8)),26) 	when X"1D", -- F1
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,46.2493,SUSTAIN_OFFSET(9)+RELEASE_OFFSET(9)),26)					when X"1E", -- F#1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),FS,48.9995,SUSTAIN_OFFSET(10)+RELEASE_OFFSET(10)),26) 	when X"1F", -- G1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),FS,51.9130,SUSTAIN_OFFSET(11)+RELEASE_OFFSET(11)),26) 	when X"20", -- G#1
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,55.0000,SUSTAIN_OFFSET(12)+RELEASE_OFFSET(12)),26)					when X"21", -- A1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),FS,58.2705,SUSTAIN_OFFSET(13)+RELEASE_OFFSET(13)),26) 	when X"22", -- A#1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),FS,61.7354,SUSTAIN_OFFSET(14)+RELEASE_OFFSET(14)),26) 	when X"23", -- B1
																																				  
																																				  
				-- Octave 2                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,65.4064,SUSTAIN_OFFSET(15)+RELEASE_OFFSET(15)),26)					when X"24", -- C2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),FS,69.2957,SUSTAIN_OFFSET(16)+RELEASE_OFFSET(16)),26)	when X"25", -- C#2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),FS,73.4162,SUSTAIN_OFFSET(17)+RELEASE_OFFSET(17)),26) 	when X"26", -- D2
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,77.7817,SUSTAIN_OFFSET(18)+RELEASE_OFFSET(18)),26)					when X"27", -- D#2 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),FS,82.4069,SUSTAIN_OFFSET(19)+RELEASE_OFFSET(19)),26) 	when X"28", -- E2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),FS,87.3071,SUSTAIN_OFFSET(20)+RELEASE_OFFSET(20)),26) 	when X"29", -- F2
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,92.4986,SUSTAIN_OFFSET(21)+RELEASE_OFFSET(21),26)					when X"2A", -- F#2 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),FS,97.9989,SUSTAIN_OFFSET(22)+RELEASE_OFFSET(22)),26) 	when X"2B", -- G2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),FS,103.826,SUSTAIN_OFFSET(23)+RELEASE_OFFSET(23)),26) 	when X"2C", -- G#2
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,110.000,SUSTAIN_OFFSET(24)+RELEASE_OFFSET(24)),26)					when X"2D", -- A2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),FS,116.541,SUSTAIN_OFFSET(25)+RELEASE_OFFSET(25)),26) 	when X"2E", -- A#2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),FS,123.471,SUSTAIN_OFFSET(26)+RELEASE_OFFSET(26)),26) 	when X"2F", -- B2
																																				  
																																				  
				-- Octave 3                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,130.813,SUSTAIN_OFFSET(27)+RELEASE_OFFSET(27)),26)					when X"30", -- C3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),FS,138.591,SUSTAIN_OFFSET(28)+RELEASE_OFFSET(28)),26) 	when X"31", -- C#3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),FS,146.832,SUSTAIN_OFFSET(29)+RELEASE_OFFSET(29)),26) 	when X"32", -- D3
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,155.563,SUSTAIN_OFFSET(30)+RELEASE_OFFSET(30)),26)					when X"33", -- D#3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),FS,164.814,SUSTAIN_OFFSET(31)+RELEASE_OFFSET(31)),26) 	when X"34", -- E3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),FS,174.614,SUSTAIN_OFFSET(32)+RELEASE_OFFSET(32)),26) 	when X"35", -- F3
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,184.997,SUSTAIN_OFFSET(33)+RELEASE_OFFSET(33)),26)					when X"36", -- F#3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),FS,195.998,SUSTAIN_OFFSET(34)+RELEASE_OFFSET(34)),26) 	when X"37", -- G3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),FS,207.652,SUSTAIN_OFFSET(35)+RELEASE_OFFSET(35)),26) 	when X"38", -- G#3
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,220.000,SUSTAIN_OFFSET(36)+RELEASE_OFFSET(36)),26)					when X"39", -- A3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),FS,233.082,SUSTAIN_OFFSET(37)+RELEASE_OFFSET(37)),26) 	when X"3A", -- A#3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),FS,246.942,SUSTAIN_OFFSET(38)+RELEASE_OFFSET(38)),26) 	when X"3B", -- B3
																																				  
																																				  
				-- Octave 4                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,261.626,SUSTAIN_OFFSET(39)+RELEASE_OFFSET(39)),26)					when X"3C", -- C4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),FS,277.183,SUSTAIN_OFFSET(40)+RELEASE_OFFSET(40)),26) 	when X"3D", -- C#4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),FS,293.665,SUSTAIN_OFFSET(41)+RELEASE_OFFSET(41)),26) 	when X"3E", -- D4
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,311.127,SUSTAIN_OFFSET(42)+RELEASE_OFFSET(42)),26)					when X"3F", -- D#4 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),FS,329.628,SUSTAIN_OFFSET(43)+RELEASE_OFFSET(43)),26) 	when X"40", -- E4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),FS,349.228,SUSTAIN_OFFSET(44)+RELEASE_OFFSET(44)),26) 	when X"41", -- F4
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,369.994,SUSTAIN_OFFSET(45)+RELEASE_OFFSET(45),26)					when X"42", -- F#4 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),FS,391.995,SUSTAIN_OFFSET(46)+RELEASE_OFFSET(46)),26) 	when X"43", -- G4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),FS,415.305,SUSTAIN_OFFSET(47)+RELEASE_OFFSET(47)),26) 	when X"44", -- G#4
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,440.000,SUSTAIN_OFFSET(48)+RELEASE_OFFSET(48)),26)					when X"45", -- A4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),FS,466.164,SUSTAIN_OFFSET(49)+RELEASE_OFFSET(49)),26) 	when X"46", -- A#4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),FS,493.883,SUSTAIN_OFFSET(50)+RELEASE_OFFSET(50)),26) 	when X"47", -- B4
																																				  
																																				  
				-- Octave 5                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,523.251,SUSTAIN_OFFSET(51)+RELEASE_OFFSET(51)),26)					when X"48", -- C5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),FS,554.365,SUSTAIN_OFFSET(52)+RELEASE_OFFSET(52)),26) 	when X"49", -- C#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),FS,587.330,SUSTAIN_OFFSET(53)+RELEASE_OFFSET(53)),26) 	when X"4A", -- D5
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,622.254,SUSTAIN_OFFSET(54)+RELEASE_OFFSET(54)),26)					when X"4B", -- D#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),FS,659.255,SUSTAIN_OFFSET(55)+RELEASE_OFFSET(55)),26) 	when X"4C", -- E5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),FS,698.456,SUSTAIN_OFFSET(56)+RELEASE_OFFSET(56)),26) 	when X"4D", -- F5
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,739.989,SUSTAIN_OFFSET(57)+RELEASE_OFFSET(57),26)					when X"4E", -- F#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),FS,783.991,SUSTAIN_OFFSET(58)+RELEASE_OFFSET(58)),26) 	when X"4F", -- G5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),FS,830.609,SUSTAIN_OFFSET(59)+RELEASE_OFFSET(59)),26) 	when X"50", -- G#5
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,880.000,SUSTAIN_OFFSET(60)+RELEASE_OFFSET(60)),26)					when X"51", -- A5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),FS,932.328,SUSTAIN_OFFSET(61)+RELEASE_OFFSET(61)),26) 	when X"52", -- A#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),FS,987.767,SUSTAIN_OFFSET(62)+RELEASE_OFFSET(62)),26) 	when X"53", -- B5
																																				  
																																				 
				-- Octave 6                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1046.50,SUSTAIN_OFFSET(63)+RELEASE_OFFSET(63)),26)					when X"54", -- C6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),FS,1108.73,SUSTAIN_OFFSET(64)+RELEASE_OFFSET(64)),26) 	when X"55", -- C#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),FS,1174.66,SUSTAIN_OFFSET(65)+RELEASE_OFFSET(65)),26) 	when X"56", -- D6
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1244.51,SUSTAIN_OFFSET(66)+RELEASE_OFFSET(66)),26)					when X"57", -- D#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),FS,1318.51,SUSTAIN_OFFSET(67)+RELEASE_OFFSET(67)),26) 	when X"58", -- E6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),FS,1396.91,SUSTAIN_OFFSET(68)+RELEASE_OFFSET(68)),26) 	when X"59", -- F6
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1479.98,SUSTAIN_OFFSET(69)+RELEASE_OFFSET(69)),26)					when X"5A", -- F#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),FS,1567.98,SUSTAIN_OFFSET(70)+RELEASE_OFFSET(70)),26) 	when X"5B", -- G6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),FS,1661.22,SUSTAIN_OFFSET(71)+RELEASE_OFFSET(71)),26) 	when X"5C", -- G#6
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1760.00,SUSTAIN_OFFSET(72)+RELEASE_OFFSET(72)),26)					when X"5D", -- A6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),FS,1864.66,SUSTAIN_OFFSET(73)+RELEASE_OFFSET(73)),26) 	when X"5E", -- A#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),FS,1975.53,SUSTAIN_OFFSET(74)+RELEASE_OFFSET(74)),26) 	when X"5F", -- B6
																																				  
																																				  
				-- Octave 7                                                                                                                       
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2093.00,SUSTAIN_OFFSET(75)+RELEASE_OFFSET(75)),26)					when X"60", -- C7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),FS,2217.46,SUSTAIN_OFFSET(76)+RELEASE_OFFSET(76)),26) 	when X"61", -- C#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),FS,2349.32,SUSTAIN_OFFSET(77)+RELEASE_OFFSET(77)),26) 	when X"62", -- D7
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2489.02,SUSTAIN_OFFSET(78)+RELEASE_OFFSET(78)),26)					when X"63", -- D#7 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),FS,2637.02,SUSTAIN_OFFSET(79)+RELEASE_OFFSET(79)),26) 	when X"64", -- E7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),FS,2793.83,SUSTAIN_OFFSET(80)+RELEASE_OFFSET(80)),26) 	when X"65", -- F7
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2959.96,SUSTAIN_OFFSET(81)+RELEASE_OFFSET(81),26)					when X"66", -- F#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),FS,3135.96,SUSTAIN_OFFSET(82)+RELEASE_OFFSET(82)),26) 	when X"67", -- G7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),FS,3322.44,SUSTAIN_OFFSET(83)+RELEASE_OFFSET(83)),26) 	when X"68", -- G#7
																																				  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,3520.00,SUSTAIN_OFFSET(84)+RELEASE_OFFSET(84)),26)					when X"69", -- A7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),FS,3729.31,SUSTAIN_OFFSET(85)+RELEASE_OFFSET(85)),26) 	when X"6A", -- A#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),FS,3951.07,SUSTAIN_OFFSET(86)+RELEASE_OFFSET(86)),26) 	when X"6B", -- B7
				
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,4186.01,SUSTAIN_OFFSET(87)+RELEASE_OFFSET(87)),26) 					when X"6C" -- C8
				
				to_unsigned(0,26) when others;

	sustainEndOffsetAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainEndOffsetAddr_In <=
				
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,27.5,RELEASE_OFFSET(0)),26)						when X"15", -- A0 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),FS,29.1353,RELEASE_OFFSET(1)),26) 	when X"16", -- A#0
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),FS,30.8677,RELEASE_OFFSET(2)),26) 	when X"17", -- B0
																															  
				-- Octave 1                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,32.7032,RELEASE_OFFSET(3)),26)					when X"18", -- C1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),FS,34.6479,RELEASE_OFFSET(4)),26) 	when X"19", -- C#1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),FS,36.7081,RELEASE_OFFSET(5)),26) 	when X"1A", -- D1
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,38.8909,RELEASE_OFFSET(6)),26)					when X"1B", -- D#1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),FS,41.2035,RELEASE_OFFSET(7)),26) 	when X"1C", -- E1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),FS,43.6536,RELEASE_OFFSET(8)),26) 	when X"1D", -- F1
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,46.2493,RELEASE_OFFSET(9)),26)					when X"1E", -- F#1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),FS,48.9995,RELEASE_OFFSET(10)),26) 	when X"1F", -- G1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),FS,51.9130,RELEASE_OFFSET(11)),26) 	when X"20", -- G#1
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,55.0000,RELEASE_OFFSET(12)),26)					when X"21", -- A1 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),FS,58.2705,RELEASE_OFFSET(13)),26) 	when X"22", -- A#1
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),FS,61.7354,RELEASE_OFFSET(14)),26) 	when X"23", -- B1
																															  
																															  
				-- Octave 2                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,65.4064,RELEASE_OFFSET(15)),26)					when X"24", -- C2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),FS,69.2957,RELEASE_OFFSET(16)),26) when X"25", -- C#2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),FS,73.4162,RELEASE_OFFSET(17)),26) when X"26", -- D2
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,77.7817,RELEASE_OFFSET(18)),26)					when X"27", -- D#2 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),FS,82.4069,RELEASE_OFFSET(19)),26) when X"28", -- E2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),FS,87.3071,RELEASE_OFFSET(20)),26) when X"29", -- F2
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,92.4986,RELEASE_OFFSET(21),26)					when X"2A", -- F#2 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),FS,97.9989,RELEASE_OFFSET(22)),26) when X"2B", -- G2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),FS,103.826,RELEASE_OFFSET(23)),26) when X"2C", -- G#2
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,110.000,RELEASE_OFFSET(24)),26)					when X"2D", -- A2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),FS,116.541,RELEASE_OFFSET(25)),26) when X"2E", -- A#2
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),FS,123.471,RELEASE_OFFSET(26)),26) when X"2F", -- B2
																															  
																															  
				-- Octave 3                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,130.813,RELEASE_OFFSET(27)),26)					when X"30", -- C3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),FS,138.591,RELEASE_OFFSET(28)),26) when X"31", -- C#3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),FS,146.832,RELEASE_OFFSET(29)),26) when X"32", -- D3
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,155.563,RELEASE_OFFSET(30)),26)					when X"33", -- D#3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),FS,164.814,RELEASE_OFFSET(31)),26) when X"34", -- E3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),FS,174.614,RELEASE_OFFSET(32)),26) when X"35", -- F3
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,184.997,RELEASE_OFFSET(33)),26)					when X"36", -- F#3 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),FS,195.998,RELEASE_OFFSET(34)),26) when X"37", -- G3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),FS,207.652,RELEASE_OFFSET(35)),26) when X"38", -- G#3
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,220.000,RELEASE_OFFSET(36)),26)					when X"39", -- A3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),FS,233.082,RELEASE_OFFSET(37)),26) when X"3A", -- A#3
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),FS,246.942,RELEASE_OFFSET(38)),26) when X"3B", -- B3
																															  
																															  
				-- Octave 4                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,261.626,RELEASE_OFFSET(39)),26)					when X"3C", -- C4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),FS,277.183,RELEASE_OFFSET(40)),26) when X"3D", -- C#4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),FS,293.665,RELEASE_OFFSET(41)),26) when X"3E", -- D4
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,311.127,RELEASE_OFFSET(42)),26)					when X"3F", -- D#4 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),FS,329.628,RELEASE_OFFSET(43)),26) when X"40", -- E4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),FS,349.228,RELEASE_OFFSET(44)),26) when X"41", -- F4
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,369.994,RELEASE_OFFSET(45),26)					when X"42", -- F#4 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),FS,391.995,RELEASE_OFFSET(46)),26) when X"43", -- G4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),FS,415.305,RELEASE_OFFSET(47)),26) when X"44", -- G#4
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,440.000,RELEASE_OFFSET(48)),26)					when X"45", -- A4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),FS,466.164,RELEASE_OFFSET(49)),26) when X"46", -- A#4
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),FS,493.883,RELEASE_OFFSET(50)),26) when X"47", -- B4
																															  
																															  
				-- Octave 5                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,523.251,RELEASE_OFFSET(51)),26)					when X"48", -- C5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),FS,554.365,RELEASE_OFFSET(52)),26) when X"49", -- C#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),FS,587.330,RELEASE_OFFSET(53)),26) when X"4A", -- D5
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,622.254,RELEASE_OFFSET(54)),26)					when X"4B", -- D#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),FS,659.255,RELEASE_OFFSET(55)),26) when X"4C", -- E5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),FS,698.456,RELEASE_OFFSET(56)),26) when X"4D", -- F5
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,739.989,RELEASE_OFFSET(57),26)					when X"4E", -- F#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),FS,783.991,RELEASE_OFFSET(58)),26) when X"4F", -- G5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),FS,830.609,RELEASE_OFFSET(59)),26) when X"50", -- G#5
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,880.000,RELEASE_OFFSET(60)),26)					when X"51", -- A5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),FS,932.328,RELEASE_OFFSET(61)),26) when X"52", -- A#5
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),FS,987.767,RELEASE_OFFSET(62)),26) when X"53", -- B5
																															  
																															  
				-- Octave 6                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1046.50,RELEASE_OFFSET(63)),26)					when X"54", -- C6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),FS,1108.73,RELEASE_OFFSET(64)),26) when X"55", -- C#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),FS,1174.66,RELEASE_OFFSET(65)),26) when X"56", -- D6
																															  ,
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1244.51,RELEASE_OFFSET(66)),26)					when X"57", -- D#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),FS,1318.51,RELEASE_OFFSET(67)),26) when X"58", -- E6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),FS,1396.91,RELEASE_OFFSET(68)),26) when X"59", -- F6
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1479.98,RELEASE_OFFSET(69)),26)					when X"5A", -- F#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),FS,1567.98,RELEASE_OFFSET(70)),26) when X"5B", -- G6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),FS,1661.22,RELEASE_OFFSET(71)),26) when X"5C", -- G#6
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1760.00,RELEASE_OFFSET(72)),26)					when X"5D", -- A6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),FS,1864.66,RELEASE_OFFSET(73)),26) when X"5E", -- A#6
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),FS,1975.53,RELEASE_OFFSET(74)),26) when X"5F", -- B6
																															  
																															  
				-- Octave 7                                                                                                   
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2093.00,RELEASE_OFFSET(75)),26)					when X"60", -- C7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),FS,2217.46,RELEASE_OFFSET(76)),26) when X"61", -- C#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),FS,2349.32,RELEASE_OFFSET(77)),26) when X"62", -- D7
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2489.02,RELEASE_OFFSET(78)),26)					when X"63", -- D#7 
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),FS,2637.02,RELEASE_OFFSET(79)),26) when X"64", -- E7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),FS,2793.83,RELEASE_OFFSET(80)),26) when X"65", -- F7
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2959.96,RELEASE_OFFSET(81),26)					when X"66", -- F#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),FS,3135.96,RELEASE_OFFSET(82)),26) when X"67", -- G7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),FS,3322.44,RELEASE_OFFSET(83)),26) when X"68", -- G#7
																															  
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,3520.00,RELEASE_OFFSET(84)),26)					when X"69", -- A7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),FS,3729.31,RELEASE_OFFSET(85)),26) when X"6A", -- A#7
				to_unsigned(getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),FS,3951.07,RELEASE_OFFSET(86)),26) when X"6B", -- B7
				
				to_unsigned(getSustainAddr(SAMPLES_PER_WAVETABLE,FS,4186.01,RELEASE_OFFSET(87)),26) 				when X"6C" -- C8
				
				to_unsigned(0,26) when others;
				





	maxSamples_ROM :
  with cmdKeyboard(7 downto 0) select
			maxSamples_In <=
				
				-- Interpolated notes
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),26)		when X"19",	-- A#0
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),26)		when X"1A",	-- B0
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),26)		when X"19",	-- C#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),26)		when X"1A",	-- D1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),26)		when X"1C", -- E1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),26)		when X"1D",	-- F1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),26)		when X"1F", -- G1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),26)		when X"20", -- G#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),26)		when X"22", -- A#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),26)		when X"23", -- B1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),26)		when X"25",	-- C#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),26)		when X"26", -- D2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),26)		when X"28",	-- E2 
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),26)		when X"29", -- F2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),26)		when X"2B",	-- G2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),26)		when X"2C",	-- G#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),26)		when X"2E", -- A#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),26)		when X"2F",	-- B2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),26)		when X"31", -- C#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),26)		when X"32", -- D3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),26)		when X"34", -- E3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),26)		when X"35", -- F3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),26)		when X"37", -- G3 
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),26)		when X"38", -- G#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),26)		when X"3A", -- A#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),26)		when X"3B", -- B3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),26)		when X"3D", -- C#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),26)		when X"3E", -- D4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),26)		when X"40", -- E4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),26)		when X"41", -- F4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),26)		when X"43", -- G4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),26)		when X"44", -- G#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),26)		when X"46", -- A#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),26)		when X"47",	-- B4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),26)		when X"49",	-- C#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),26)		when X"4A", -- D5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),26)		when X"4C", -- E5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),26)		when X"4D", -- F5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),26)		when X"4F", -- G5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),26)		when X"50", -- G#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),26)		when X"52", -- A#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),26)		when X"53",	-- B5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),26)		when X"55", -- C#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),26)		when X"56", -- D6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),26)		when X"58", -- E6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),26)		when X"59", -- F6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),26)		when X"5B", -- G6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),26)		when X"5C", -- G#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),26)		when X"5E", -- A#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),26)		when X"5F", -- B6				
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),26)		when X"61", -- C#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),26)		when X"62", -- D7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),26)		when X"64", -- E7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),26)		when X"65", -- F7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),26)		when X"67", -- G7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),26)		when X"68", -- G#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),26)		when X"6A", -- A#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),26)		when X"6B", -- B7					
				
				to_unsigned(SAMPLES_PER_WAVETABLE,26) when others;  -- All the notes stored in memory, A0, C1,D#1,F#1,A#1, C2,D#2,F#2,A#2, .... C8
			
----------------------------------------------------------------------------------
-- PIPELINED SUM
--      Manage the sums of all notes, is organized like a tree
---------------------------------------------------------------------------------- 


--Level 0
genSumLevel0:
for i in 0 to (NUM_NOTES/2)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>notesGen_samplesOut(i*2),b_in=>notesGen_samplesOut(i*2+1),c_out=>sampleOutAux_S0(i));
end generate;

--Level 1
genSumLevel1:
for i in 0 to (NUM_NOTES/4)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S0(i*2),b_in=>sampleOutAux_S0(i*2+1),c_out=>sampleOutAux_S1(i));
end generate;

--Level 2
genSumLevel2:
for i in 0 to (NUM_NOTES/8)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S1(i*2),b_in=>sampleOutAux_S1(i*2+1),c_out=>sampleOutAux_S2(i));
end generate;

--Level 3
genSumLevel3:
for i in 0 to (NUM_NOTES/16)-1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S2(i*2),b_in=>sampleOutAux_S2(i*2+1),c_out=>sampleOutAux_S3(i));
end generate;

-- Level 4
genSumLevel4:
for i in 0 to 1 generate
    sum_i: MyFiexedSum
    generic map(WL=>16)
    port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S3(i*2),b_in=>sampleOutAux_S3(i*2+1),c_out=>sampleOutAux_S4(i));
end generate;

sum_L4: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S3(4),b_in=>sampleOutAux_S2(10),c_out=>sampleOutAux_S4(2));

-- Level 5
sum_L5: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S4(0),b_in=>sampleOutAux_S4(1),c_out=>sampleOutAux_S5);

-- Level 6, final sum
sum_L6: MyFiexedSum
generic map(WL=>16)
port map( rst_n =>rst_n, clk=>clk,a_in=>sampleOutAux_S5,b_in=>sampleOutAux_S4(2),c_out=>sampleOutAux_S6);


sampleOut <= sampleOutAux_S6;

----------------------------------------------------------------------------------
-- NOTES GENERATOR
--      Creation of the notes generators components,
--		the las one are not in the for generate
----------------------------------------------------------------------------------

genNotes:
for i in 0 to (NUM_NOTES/3)-1 generate
    SimpleNoteGen0: SimpleNoteGen
    generic map( 
             WL=>WL,FS=>FS,BASE_FREQ=>iniFreq(i*3), SUSTAIN_OFFSET=>sustainOffset(i*3), RELEASE_OFFSET=>releaseOffset(i*3),
             START_ADDR=>iniVals(i*2) ,END_ADDR=>iniVals(i*2+1)
            )
    port map(
        -- Host side
        rst_n   =>  rst_n,
        clk     => clk,
        cen_in  =>notesEnable(i*3),
        interpolateSampleRqt  =>sampleRqt,
        sample_out  =>notesGen_samplesOut(i*3),
    
        --Mem side
        samples_in  =>mem_sampleIn,
        memAck  =>muxMemAck(i*3),
        addr_out  =>notesGen_addrOut(i*3),
		sample_inRqt =>muxSampleInRqt(i*3)
      );
      
      InterpolatedNoteGen1:InterpolatedNoteGen
      generic map( FS=>FS,TARGET_NOTE=>iniFreq(i*3+1), BASE_NOTE=>iniFreq(i*3),
                   SUSTAIN_OFFSET=>sustainOffset(i*3+1), RELEASE_OFFSET=>releaseOffset(i*3+1),
                   START_ADDR=>iniVals(i*2), END_ADDR=>iniVals(i*2+1)
              )        
      port map(
            -- Host side
            rst_n   =>  rst_n,
            clk     => clk,
            cen_in  =>notesEnable(i*3+1),
            interpolateSampleRqt  =>sampleRqt,
            sample_out  =>notesGen_samplesOut(i*3+1),
        
            --Mem side
            samples_in  =>mem_sampleIn,
            memAck  =>muxMemAck(i*3+1),
            addr_out  =>notesGen_addrOut(i*3+1),
			sample_inRqt =>muxSampleInRqt(i*3+1)
        );

      InterpolatedNoteGen2:InterpolatedNoteGen
      generic map( FS=>FS,TARGET_NOTE=>iniFreq(i*3+2), BASE_NOTE=>iniFreq(i*3),
                   SUSTAIN_OFFSET=>sustainOffset(i*3+2), RELEASE_OFFSET=>releaseOffset(i*3+2),
                   START_ADDR=>iniVals(i*2), END_ADDR=>iniVals(i*2+1)
              )        
      port map(
            -- Host side
            rst_n   =>  rst_n,
            clk     => clk,
            cen_in  =>notesEnable(i*3+2),
            interpolateSampleRqt  =>sampleRqt,
            sample_out  =>notesGen_samplesOut(i*3+2),
        
            --Mem side
            samples_in  =>mem_sampleIn,
            memAck  =>muxMemAck(i*3+2),
            addr_out  =>notesGen_addrOut(i*3+2),
			sample_inRqt =>muxSampleInRqt(i*3+2)
        );

end generate;

-- C8
SimpleNoteGen0: SimpleNoteGen
    generic map( 
         WL=>WL,FS=>FS,BASE_FREQ=>iniFreq(87), SUSTAIN_OFFSET=>sustainOffset(87), RELEASE_OFFSET=>releaseOffset(87),
         START_ADDR=>iniVals(58) ,END_ADDR=>iniVals(59)
        )
  port map(
    -- Host side
    rst_n   =>  rst_n,
    clk     => clk,
    cen_in  =>notesEnable(87),
    interpolateSampleRqt  =>sampleRqt,
    sample_out  =>notesGen_samplesOut(87),

    --Mem side
    samples_in  =>mem_sampleIn,
    memAck  =>muxMemAck(87),
    addr_out  =>notesGen_addrOut(87),
	sample_inRqt =>muxSampleInRqt(87)
  );

 
----------------------------------------------------------------------------------
-- MEM READ ARBITRATOR
--      Manage the read access of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsm:
process(rst_n,clk,mem_ack)
    type states is ( checkGeneratorRqt, waitMemAck0);
    
    variable state      :   states;
    variable turnCntr   :   unsigned(6 downto 0);
    variable cntr       :   unsigned(1 downto 0);
    variable addrToRead :   std_logic_vector(25 downto 0);
begin
    
    mem_addrOut <= addrToRead;
    muxMemAck <=(others=>'0');
    muxMemAck(to_integer(turnCntr)) <= mem_ack;

    if rst_n='0' then
       turnCntr := (others=>'0');
       state := checkGeneratorRqt;
       addrToRead := (others=>'0');
       cntr :=  (others=>'0');
       mem_readOut <= '1';
       
    elsif rising_edge(clk) then
        mem_readOut <= '1'; -- Just one cycle
       
        case state is
            when checkGeneratorRqt =>
                 if muxSampleInRqt(to_integer(turnCntr))='1' then
                        addrToRead := notesGen_addrOut(to_integer(turnCntr));
                        -- Order read in the next cycle
                        mem_readOut <= '0';
                        state := waitMemAck0;
                 else
                    if turnCntr=NUM_NOTES-1 then
                        turnCntr := (others=>'0');
                    else
                        turnCntr := turnCntr+1;
                    end if;     
                 end if;   
            
            when waitMemAck0 =>
                if mem_ack='1' then
                   state := checkGeneratorRqt;                
                end if;

        end case;
        
        
        
    end if;
end process;
  
end Behavioral;
