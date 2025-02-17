module ip_analyzer (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg packet_complete,
    output reg [3:0] version,
    output reg [3:0] ihl,
    output reg [7:0] tos,
    output reg [15:0] total_length,
    output reg [15:0] identification,
    output reg [2:0] flags,
    output reg [12:0] fragment_offset,
    output reg [7:0] ttl,
    output reg [7:0] protocol,
    output reg [15:0] header_checksum,
    output reg [31:0] source_ip,
    output reg [31:0] dest_ip
);

    // State definitions
    localparam IDLE = 4'b0000;
    localparam VER_IHL = 4'b0001;
    localparam TOS = 4'b0010;
    localparam LENGTH = 4'b0011;
    localparam ID = 4'b0100;
    localparam FLAGS_FRAG = 4'b0101;
    localparam TTL_PROTO = 4'b0110;
    localparam CHECKSUM = 4'b0111;
    localparam SRC_IP = 4'b1000;
    localparam DST_IP = 4'b1001;

    reg [3:0] current_state, next_state;
    reg [3:0] byte_counter;

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            byte_counter <= 0;
            packet_complete <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (data_valid) begin
                        version <= data_in[7:4];
                        ihl <= data_in[3:0];
                        byte_counter <= 0;
                    end
                end
                
                TOS: begin
                    if (data_valid) begin
                        tos <= data_in;
                    end
                end
                
                LENGTH: begin
                    if (data_valid) begin
                        total_length <= {total_length[7:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                ID: begin
                    if (data_valid) begin
                        identification <= {identification[7:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                FLAGS_FRAG: begin
                    if (data_valid) begin
                        if (byte_counter == 0) begin
                            flags <= data_in[7:5];
                            fragment_offset[12:8] <= data_in[4:0];
                        end else begin
                            fragment_offset[7:0] <= data_in;
                        end
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                TTL_PROTO: begin
                    if (data_valid) begin
                        if (byte_counter == 0) ttl <= data_in;
                        else protocol <= data_in;
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                CHECKSUM: begin
                    if (data_valid) begin
                        header_checksum <= {header_checksum[7:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                SRC_IP: begin
                    if (data_valid) begin
                        source_ip <= {source_ip[23:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                DST_IP: begin
                    if (data_valid) begin
                        dest_ip <= {dest_ip[23:0], data_in};
                        byte_counter <= byte_counter + 1;
                        if (byte_counter == 3) packet_complete <= 1;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = data_valid ? TOS : IDLE;
            TOS: next_state = data_valid ? LENGTH : TOS;
            LENGTH: next_state = (byte_counter == 2) ? ID : LENGTH;
            ID: next_state = (byte_counter == 2) ? FLAGS_FRAG : ID;
            FLAGS_FRAG: next_state = (byte_counter == 2) ? TTL_PROTO : FLAGS_FRAG;
            TTL_PROTO: next_state = (byte_counter == 2) ? CHECKSUM : TTL_PROTO;
            CHECKSUM: next_state = (byte_counter == 2) ? SRC_IP : CHECKSUM;
            SRC_IP: next_state = (byte_counter == 4) ? DST_IP : SRC_IP;
            DST_IP: next_state = packet_complete ? IDLE : DST_IP;
            default: next_state = IDLE;
        endcase
    end

endmodule
