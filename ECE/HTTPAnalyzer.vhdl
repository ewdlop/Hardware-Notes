library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HTTPAnalyzer is
    Port (
        -- System signals
        clk           : in  std_logic;
        reset         : in  std_logic;
        
        -- Ethernet input interface
        rx_data       : in  std_logic_vector(7 downto 0);
        rx_valid      : in  std_logic;
        rx_last       : in  std_logic;
        
        -- Analysis output interface
        method_out    : out std_logic_vector(23 downto 0);  -- GET/POST/PUT etc
        uri_length    : out std_logic_vector(15 downto 0);
        status_code   : out std_logic_vector(15 downto 0);  -- For responses
        content_len   : out std_logic_vector(31 downto 0);
        is_request    : out std_logic;
        is_response   : out std_logic;
        header_done   : out std_logic;
        packet_done   : out std_logic;
        
        -- Statistics interface
        req_count     : out std_logic_vector(31 downto 0);
        resp_count    : out std_logic_vector(31 downto 0);
        error_count   : out std_logic_vector(31 downto 0)
    );
end HTTPAnalyzer;

architecture Behavioral of HTTPAnalyzer is
    -- State machine types
    type parse_state is (IDLE, TCP_HEADER, HTTP_START, METHOD_PARSE, 
                        URI_PARSE, VERSION_PARSE, HEADER_PARSE, 
                        BODY_PARSE, COMPLETE);
    signal current_state : parse_state;
    
    -- Buffer for pattern matching
    type buffer_array is array (0 to 15) of std_logic_vector(7 downto 0);
    signal match_buffer : buffer_array;
    signal buffer_index : integer range 0 to 15;
    
    -- HTTP parsing signals
    signal byte_counter   : unsigned(31 downto 0);
    signal header_counter : unsigned(15 downto 0);
    signal content_length : unsigned(31 downto 0);
    signal found_content_len : std_logic;
    
    -- HTTP method recognition constants
    constant GET_METHOD    : string := "GET ";
    constant POST_METHOD   : string := "POST";
    constant PUT_METHOD    : string := "PUT ";
    constant HTTP_VERSION  : string := "HTTP/1.";
    
    -- Statistics counters
    signal request_counter  : unsigned(31 downto 0);
    signal response_counter : unsigned(31 downto 0);
    signal error_counter    : unsigned(31 downto 0);
    
begin
    -- Main HTTP parsing process
    process(clk, reset)
        variable temp_char : character;
        variable is_header_end : boolean;
        
        -- Helper function to convert std_logic_vector to character
        function to_char(vec : std_logic_vector(7 downto 0)) return character is
        begin
            return character'val(to_integer(unsigned(vec)));
        end function;
        
        -- Helper function to check if character is digit
        function is_digit(vec : std_logic_vector(7 downto 0)) return boolean is
            variable char_val : integer;
        begin
            char_val := to_integer(unsigned(vec));
            return (char_val >= 48 and char_val <= 57);
        end function;
        
    begin
        if reset = '1' then
            current_state <= IDLE;
            byte_counter <= (others => '0');
            header_counter <= (others => '0');
            content_length <= (others => '0');
            found_content_len <= '0';
            is_request <= '0';
            is_response <= '0';
            header_done <= '0';
            packet_done <= '0';
            request_counter <= (others => '0');
            response_counter <= (others => '0');
            error_counter <= (others => '0');
            
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    if rx_valid = '1' then
                        -- Start collecting TCP payload
                        current_state <= TCP_HEADER;
                        byte_counter <= (others => '0');
                        buffer_index <= 0;
                        header_done <= '0';
                        packet_done <= '0';
                    end if;
                
                when TCP_HEADER =>
                    if rx_valid = '1' then
                        byte_counter <= byte_counter + 1;
                        
                        -- After TCP header (20 bytes), start HTTP parsing
                        if byte_counter = 20 then
                            current_state <= HTTP_START;
                            match_buffer(0) <= rx_data;
                            buffer_index <= 1;
                        end if;
                    end if;
                
                when HTTP_START =>
                    if rx_valid = '1' then
                        match_buffer(buffer_index) <= rx_data;
                        
                        -- Check if it's a request or response
                        if buffer_index = 3 then
                            temp_char := to_char(match_buffer(0));
                            
                            -- Check for HTTP methods
                            if match_buffer(0 to 3) = GET_METHOD then
                                is_request <= '1';
                                method_out <= x"474554"; -- "GET"
                                current_state <= URI_PARSE;
                            elsif match_buffer(0 to 3) = POST_METHOD then
                                is_request <= '1';
                                method_out <= x"504F5354"; -- "POST"
                                current_state <= URI_PARSE;
                            elsif match_buffer(0 to 3) = PUT_METHOD then
                                is_request <= '1';
                                method_out <= x"505554"; -- "PUT"
                                current_state <= URI_PARSE;
                            -- Check for HTTP response
                            elsif match_buffer(0 to 4) = HTTP_VERSION then
                                is_response <= '1';
                                current_state <= HEADER_PARSE;
                            else
                                error_counter <= error_counter + 1;
                                current_state <= IDLE;
                            end if;
                        end if;
                        
                        buffer_index <= buffer_index + 1;
                    end if;
                
                when URI_PARSE =>
                    if rx_valid = '1' then
                        -- Count URI length until space
                        if rx_data = x"20" then -- space
                            uri_length <= std_logic_vector(byte_counter - 21);
                            current_state <= VERSION_PARSE;
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                    end if;
                
                when VERSION_PARSE =>
                    if rx_valid = '1' then
                        -- Look for end of first line
                        if rx_data = x"0A" then -- newline
                            current_state <= HEADER_PARSE;
                            header_counter <= (others => '0');
                        end if;
                    end if;
                
                when HEADER_PARSE =>
                    if rx_valid = '1' then
                        -- Check for Content-Length header
                        if not found_content_len then
                            match_buffer(buffer_index) <= rx_data;
                            if buffer_index = 15 then
                                -- Check if we found "Content-Length: "
                                if match_buffer(0 to 14) = x"436F6E74656E742D4C656E6774683A20" then
                                    found_content_len <= '1';
                                    content_length <= (others => '0');
                                end if;
                            end if;
                            buffer_index <= buffer_index + 1;
                        elsif found_content_len then
                            -- Parse content length value
                            if is_digit(rx_data) then
                                content_length <= content_length * 10 + 
                                                unsigned(rx_data) - x"30";
                            elsif rx_data = x"0D" then -- CR
                                content_len <= std_logic_vector(content_length);
                                found_content_len <= '0';
                            end if;
                        end if;
                        
                        -- Check for end of headers
                        if rx_data = x"0A" then -- LF
                            if header_counter = 1 then -- Empty line
                                header_done <= '1';
                                current_state <= BODY_PARSE;
                            end if;
                            header_counter <= header_counter + 1;
                        elsif rx_data = x"0D" then -- CR
                            null; -- Skip CR
                        else
                            header_counter <= (others => '0');
                        end if;
                    end if;
                
                when BODY_PARSE =>
                    if rx_valid = '1' then
                        if rx_last = '1' then
                            current_state <= COMPLETE;
                        end if;
                    end if;
                
                when COMPLETE =>
                    packet_done <= '1';
                    if is_request then
                        request_counter <= request_counter + 1;
                    elsif is_response then
                        response_counter <= response_counter + 1;
                    end if;
                    current_state <= IDLE;
                    
            end case;
        end if;
    end process;
    
    -- Output statistics
    req_count <= std_logic_vector(request_counter);
    resp_count <= std_logic_vector(response_counter);
    error_count <= std_logic_vector(error_counter);

end Behavioral;
