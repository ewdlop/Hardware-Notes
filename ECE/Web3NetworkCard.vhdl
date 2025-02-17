library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Web3NetworkCard is
    Port (
        -- System signals
        clk         : in  std_logic;
        reset       : in  std_logic;
        
        -- PCIe interface
        pcie_rx     : in  std_logic_vector(7 downto 0);
        pcie_tx     : out std_logic_vector(7 downto 0);
        pcie_valid  : in  std_logic;
        
        -- Ethernet interface
        eth_rx      : in  std_logic_vector(7 downto 0);
        eth_tx      : out std_logic_vector(7 downto 0);
        eth_valid   : in  std_logic;
        
        -- Hash accelerator interface
        hash_data   : out std_logic_vector(511 downto 0);
        hash_start  : out std_logic;
        hash_done   : in  std_logic;
        hash_result : in  std_logic_vector(255 downto 0)
    );
end Web3NetworkCard;

architecture Behavioral of Web3NetworkCard is
    -- State machine types
    type state_type is (IDLE, RECEIVE_PACKET, PROCESS_HEADER, 
                       HASH_COMPUTATION, TRANSMIT_RESPONSE);
    signal current_state, next_state : state_type;
    
    -- Packet buffer
    type packet_buffer is array (0 to 2047) of std_logic_vector(7 downto 0);
    signal rx_buffer : packet_buffer;
    signal tx_buffer : packet_buffer;
    
    -- Buffer pointers and counters
    signal rx_ptr    : unsigned(10 downto 0);
    signal tx_ptr    : unsigned(10 downto 0);
    signal byte_cnt  : unsigned(10 downto 0);
    
    -- Web3 specific signals
    signal is_web3_packet : std_logic;
    signal eth_type      : std_logic_vector(15 downto 0);
    signal protocol_ver  : std_logic_vector(7 downto 0);
    
begin
    -- Main state machine process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            rx_ptr <= (others => '0');
            tx_ptr <= (others => '0');
            byte_cnt <= (others => '0');
            is_web3_packet <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    if eth_valid = '1' then
                        current_state <= RECEIVE_PACKET;
                        rx_ptr <= (others => '0');
                    end if;
                
                when RECEIVE_PACKET =>
                    if eth_valid = '1' then
                        rx_buffer(to_integer(rx_ptr)) <= eth_rx;
                        rx_ptr <= rx_ptr + 1;
                        
                        -- Check for end of packet
                        if rx_ptr = 13 then  -- Ethernet header size
                            current_state <= PROCESS_HEADER;
                        end if;
                    end if;
                
                when PROCESS_HEADER =>
                    -- Extract Ethernet type
                    eth_type <= rx_buffer(12) & rx_buffer(13);
                    
                    -- Check if it's a Web3 packet (custom EtherType)
                    if eth_type = x"88B5" then  -- Custom EtherType for Web3
                        is_web3_packet <= '1';
                        protocol_ver <= rx_buffer(14);
                        current_state <= HASH_COMPUTATION;
                    else
                        is_web3_packet <= '0';
                        current_state <= IDLE;
                    end if;
                
                when HASH_COMPUTATION =>
                    if hash_done = '1' then
                        current_state <= TRANSMIT_RESPONSE;
                        tx_ptr <= (others => '0');
                    end if;
                
                when TRANSMIT_RESPONSE =>
                    if tx_ptr < rx_ptr then
                        eth_tx <= tx_buffer(to_integer(tx_ptr));
                        tx_ptr <= tx_ptr + 1;
                    else
                        current_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- Hash computation process
    process(clk)
    begin
        if rising_edge(clk) then
            if current_state = HASH_COMPUTATION then
                -- Prepare data for hashing
                for i in 0 to 63 loop
                    hash_data(i*8+7 downto i*8) <= rx_buffer(i+14);
                end loop;
                hash_start <= '1';
            else
                hash_start <= '0';
            end if;
        end if;
    end process;

    -- Response packet formation
    process(clk)
    begin
        if rising_edge(clk) then
            if current_state = HASH_COMPUTATION and hash_done = '1' then
                -- Copy original Ethernet header
                for i in 0 to 13 loop
                    tx_buffer(i) <= rx_buffer(i);
                end loop;
                
                -- Swap source and destination MAC addresses
                for i in 0 to 5 loop
                    tx_buffer(i) <= rx_buffer(i+6);
                    tx_buffer(i+6) <= rx_buffer(i);
                end loop;
                
                -- Add hash result
                for i in 0 to 31 loop
                    tx_buffer(i+14) <= hash_result(i*8+7 downto i*8);
                end loop;
            end if;
        end if;
    end process;

end Behavioral;
