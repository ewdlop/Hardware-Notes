library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PasswordCracker is
    Port (
        -- System signals
        clk           : in  std_logic;
        reset         : in  std_logic;
        start         : in  std_logic;
        
        -- Password configuration
        hash_target   : in  std_logic_vector(255 downto 0);
        min_length    : in  std_logic_vector(3 downto 0);
        max_length    : in  std_logic_vector(3 downto 0);
        char_set_sel  : in  std_logic_vector(2 downto 0);  -- Character set selection
        
        -- Status outputs
        busy         : out std_logic;
        found        : out std_logic;
        current_len  : out std_logic_vector(3 downto 0);
        result       : out std_logic_vector(127 downto 0)  -- Found password
    );
end PasswordCracker;

architecture Behavioral of PasswordCracker is
    -- Character set ROM components
    type char_rom is array (0 to 255) of std_logic_vector(7 downto 0);
    
    -- Define different character sets
    constant LOWERCASE_SET: char_rom := (
        x"61", x"62", x"63", x"64", x"65", x"66", x"67", x"68",  -- a-h
        x"69", x"6A", x"6B", x"6C", x"6D", x"6E", x"6F", x"70",  -- i-p
        x"71", x"72", x"73", x"74", x"75", x"76", x"77", x"78",  -- q-x
        x"79", x"7A", others => x"00"                            -- y-z
    );
    
    constant UPPERCASE_SET: char_rom := (
        x"41", x"42", x"43", x"44", x"45", x"46", x"47", x"48",  -- A-H
        x"49", x"4A", x"4B", x"4C", x"4D", x"4E", x"4F", x"50",  -- I-P
        x"51", x"52", x"53", x"54", x"55", x"56", x"57", x"58",  -- Q-X
        x"59", x"5A", others => x"00"                            -- Y-Z
    );
    
    constant DIGITS_SET: char_rom := (
        x"30", x"31", x"32", x"33", x"34", x"35", x"36", x"37",  -- 0-7
        x"38", x"39", others => x"00"                            -- 8-9
    );
    
    -- Special characters commonly used in passwords
    constant SPECIAL_SET: char_rom := (
        x"21", x"23", x"24", x"25", x"26", x"28", x"29", x"2A",  -- !#$%&()*
        x"2B", x"2C", x"2D", x"2E", x"2F", x"3F", x"40", x"5E",  -- +,-./?@^
        others => x"00"
    );
    
    -- State machine
    type cracker_state is (IDLE, INIT, GENERATE, HASH, COMPARE, INCREMENT, FOUND_PWD);
    signal state : cracker_state;
    
    -- Password generation signals
    signal current_password : std_logic_vector(127 downto 0);
    signal current_indices : std_logic_vector(127 downto 0);  -- 16 characters, 8 bits each
    signal password_length : unsigned(3 downto 0);
    signal char_set       : char_rom;
    signal char_set_size  : unsigned(7 downto 0);
    
    -- Parallel hash computation components
    type hash_array is array (0 to 3) of std_logic_vector(255 downto 0);
    signal hash_units     : hash_array;
    signal hash_valid     : std_logic_vector(3 downto 0);
    
    -- Pipeline stages for hash computation
    type pipeline_stage is record
        data    : std_logic_vector(127 downto 0);
        valid   : std_logic;
        indices : std_logic_vector(127 downto 0);
    end record;
    type pipeline_array is array (0 to 3) of pipeline_stage;
    signal pipeline : pipeline_array;
    
begin
    -- Main process for password generation and control
    process(clk, reset)
        variable next_indices : std_logic_vector(127 downto 0);
        variable carry : std_logic;
    begin
        if reset = '1' then
            state <= IDLE;
            busy <= '0';
            found <= '0';
            password_length <= (others => '0');
            current_indices <= (others => '0');
            pipeline <= (others => (data => (others => '0'), 
                                 valid => '0',
                                 indices => (others => '0')));
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if start = '1' then
                        state <= INIT;
                        busy <= '1';
                        found <= '0';
                        password_length <= unsigned(min_length);
                        
                        -- Select character set based on input
                        case char_set_sel is
                            when "000" => 
                                char_set <= LOWERCASE_SET;
                                char_set_size <= to_unsigned(26, 8);
                            when "001" => 
                                char_set <= UPPERCASE_SET;
                                char_set_size <= to_unsigned(26, 8);
                            when "010" => 
                                char_set <= DIGITS_SET;
                                char_set_size <= to_unsigned(10, 8);
                            when "011" => 
                                char_set <= SPECIAL_SET;
                                char_set_size <= to_unsigned(16, 8);
                            when others => 
                                char_set <= LOWERCASE_SET;
                                char_set_size <= to_unsigned(26, 8);
                        end case;
                    end if;
                
                when INIT =>
                    -- Initialize first password attempt
                    for i in 0 to 15 loop
                        if i < to_integer(password_length) then
                            current_indices(i*8+7 downto i*8) <= (others => '0');
                            current_password(i*8+7 downto i*8) <= char_set(0);
                        else
                            current_indices(i*8+7 downto i*8) <= (others => '0');
                            current_password(i*8+7 downto i*8) <= (others => '0');
                        end if;
                    end loop;
                    state <= GENERATE;
                
                when GENERATE =>
                    -- Load pipeline with multiple candidates
                    for i in 0 to 3 loop
                        if pipeline(i).valid = '0' then
                            pipeline(i).data <= current_password;
                            pipeline(i).valid <= '1';
                            pipeline(i).indices <= current_indices;
                            
                            -- Generate next password
                            carry := '1';
                            next_indices := current_indices;
                            
                            for j in 0 to to_integer(password_length)-1 loop
                                if carry = '1' then
                                    if unsigned(current_indices(j*8+7 downto j*8)) = char_set_size - 1 then
                                        next_indices(j*8+7 downto j*8) := (others => '0');
                                        carry := '1';
                                    else
                                        next_indices(j*8+7 downto j*8) := 
                                            std_logic_vector(unsigned(current_indices(j*8+7 downto j*8)) + 1);
                                        carry := '0';
                                    end if;
                                end if;
                            end loop;
                            
                            current_indices <= next_indices;
                            
                            -- Update password characters based on indices
                            for j in 0 to to_integer(password_length)-1 loop
                                current_password(j*8+7 downto j*8) <= 
                                    char_set(to_integer(unsigned(next_indices(j*8+7 downto j*8))));
                            end loop;
                            
                            -- Check if we need to increase password length
                            if carry = '1' then
                                if password_length = unsigned(max_length) then
                                    state <= IDLE;
                                    busy <= '0';
                                else
                                    password_length <= password_length + 1;
                                    state <= INIT;
                                end if;
                                exit;
                            end if;
                        end if;
                    end loop;
                    
                    if pipeline(3).valid = '1' then
                        state <= HASH;
                    end if;
                
                when HASH =>
                    -- Parallel hash computation
                    for i in 0 to 3 loop
                        if pipeline(i).valid = '1' then
                            -- Simplified hash computation for demonstration
                            -- In practice, implement full hash algorithm here
                            hash_units(i) <= pipeline(i).data & x"00000000000000000000000000000000";
                            hash_valid(i) <= '1';
                        end if;
                    end loop;
                    state <= COMPARE;
                
                when COMPARE =>
                    -- Compare hash results
                    for i in 0 to 3 loop
                        if hash_valid(i) = '1' and hash_units(i) = hash_target then
                            result <= pipeline(i).data;
                            current_len <= std_logic_vector(password_length);
                            state <= FOUND_PWD;
                            found <= '1';
                            busy <= '0';
                            exit;
                        end if;
                    end loop;
                    
                    -- Clear pipeline and continue
                    pipeline <= (others => (data => (others => '0'),
                                         valid => '0',
                                         indices => (others => '0')));
                    hash_valid <= (others => '0');
                    state <= GENERATE;
                
                when FOUND_PWD =>
                    if start = '0' then
                        state <= IDLE;
                    end if;
                
            end case;
        end if;
    end process;

end Behavioral;
