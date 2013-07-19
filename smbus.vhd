----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:42:31 07/05/2013 
-- Design Name: 
-- Module Name:    smbus - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library STD;
use STD.textio.all;
use IEEE.STD_LOGIC_TEXTIO.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity smbus is
    Port ( rst : in STD_LOGIC;
			  clk_p : in  STD_LOGIC;
           clk_n : in  STD_LOGIC;
           scl : out  STD_LOGIC;
           sda : inout  STD_LOGIC;
			  outclk_p : out STD_LOGIC;
			  led0 : out STD_LOGIC;
			  led1 : out STD_LOGIC;
			  led2 : out STD_LOGIC;
			  led3 : out STD_LOGIC;
			  led4 : out STD_LOGIC;
			  led5 : out STD_LOGIC;
			  led6 : out STD_LOGIC
			  );
end smbus;

architecture Behavioral of smbus is

signal clk: std_logic;
signal slowclk_enable : std_logic;
signal clk_counter : integer range 0 to 50000 := 0;
signal scl_counter : integer range 0 to 50000 := 0;
constant CLKSLOWCLK_RATIO : integer := 500;
--if we want slowclk at 400khz (allow us to do things 4x in cycle), ratio should be 500

type state_type is (state_idle, state_start, state_stop, state_send_slave_address,
   state_send_rw, state_receive_ack);
signal state_current : state_type;
signal state_next : state_type;

signal idle_counter : integer range 0 to 50000;

signal slaveaddress_counter : integer range 0 to 10;
signal slaveaddress_bits : std_logic_vector(6 downto 0);

signal receive_ack_counter : integer range 0 to 10;
--signal sda_read : std_logic;


begin

	IBUFDS_inst : IBUFDS
	generic map (
		DIFF_TERM => FALSE,
		IBUF_LOW_PWR => TRUE,
		IOSTANDARD => "DEFAULT")
	port map (
		O => clk,
		I => clk_p,
		IB => clk_n
	);
				
	slowclk_generation: process(rst, clk)
	begin
		if rst = '1' then
			clk_counter <= 0;
			slowclk_enable <= '0';
		elsif rising_edge(clk) then
			if clk_counter >= (CLKSLOWCLK_RATIO-1) then
				outclk_p <= '1';
				slowclk_enable <= '1';
				clk_counter <= 0;
			else
				slowclk_enable <= '0';
				clk_counter <= clk_counter + 1;
			end if;
		end if;
	end process;
	
	scl_generation: process(rst, clk)
	begin
		if rst = '1' then
			scl <= '0';
			scl_counter <= 0;
		elsif rising_edge(clk) then
			if slowclk_enable = '1' then
				if scl_counter = 0 then
					scl <= '1';
				elsif scl_counter = 2 then
					scl <= '0';
				end if;
					
				if scl_counter < 3 then
					scl_counter <= scl_counter+ 1;
				elsif scl_counter >= 3 then
					scl_counter <= 0;
				end if;
			end if;
		end if;
	end process;
	
	sda_generation: process(rst, clk)
		variable sda_read : std_logic;
	begin
		if rst = '1' then
			state_current <= state_idle;
			state_next <= state_start;
			idle_counter <= 0;
			sda <= '1';
			led0 <= '0';
			led1 <= '0';
			led2 <= '0';
			led3 <= '0';
			led4 <= '0';
			led5 <= '0';
			led6 <= '0';
			slaveaddress_bits <= "1110100";
		elsif rising_edge(clk) then
			if slowclk_enable = '1' then
				if state_current = state_idle then
					if scl_counter = 3 then -- middle of low scl
						sda <= '1';
						if idle_counter >= 30000  then
							state_current <= state_next;
						else
							idle_counter <= idle_counter + 1;
						end if;
					end if;
				elsif state_current = state_start then
					if	scl_counter = 1 then -- middle of high scl
						sda <= '0';
						state_current <= state_send_slave_address;
						slaveaddress_counter <= 6; -- start at msb
					end if;
				elsif state_current = state_send_slave_address then
					if scl_counter = 3 then -- middle of low scl
						sda <= slaveaddress_bits(slaveaddress_counter);
						if slaveaddress_counter = 0 then
							state_current <= state_send_rw;
						else 
							slaveaddress_counter <= slaveaddress_counter - 1;
						end if;
					end if;
				elsif state_current = state_send_rw then
					if scl_counter = 3 then
						sda <= '0';
						state_current <= state_receive_ack;
						receive_ack_counter <= 0;
					end if;
				elsif state_current = state_receive_ack then
				   
					if scl_counter = 3 then
						sda <= 'Z';
						receive_ack_counter <= 1;
						led4 <= '1';
					elsif scl_counter = 1 and receive_ack_counter = 1 then
						if sda = '0' then
							led0 <= '1';
						elsif sda = '1' then
							led1 <= '1';
						else
							led0 <= '1';
							led1 <= '1';
						end if;
						state_current <= state_idle;
						state_next <= state_idle;
					end if;
				end if;
			end if;
		end if;
	end process;


end Behavioral;

